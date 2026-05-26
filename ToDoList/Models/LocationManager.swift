import FirebaseFirestore
import CoreLocation
import SwiftUI
import MapKit
import Network

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var backgroundTimer: Timer? // Timer for background location updates
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    @Published var location: CLLocation? // Stores user's current location
    @Published var locationStatus: CLAuthorizationStatus? // Track authorization status
    
    @Published var userId: String? // User's ID for items fetching
    
    @Published var fetchedItems: [Item] = []
    
    // Time interval for periodic checks (30 minutes)
    private let checkInterval: TimeInterval = 1800
    
    // Create a serial queue for ETA requests
    private static let etaRequestQueue = DispatchQueue(label: "com.Levi.ToDoList.ETARequestQueue")
    private static var pendingETARequests = 0
    private static let maxConcurrentRequests = 3 // Further reduced for better reliability
    
    // Network connectivity monitoring
    private let networkMonitor = NWPathMonitor()
    private var isOnCellular = false
    private var hasConnectivity = true
    private var networkQuality: NetworkQuality = .good
    
    // For caching previous ETAs to reduce redundant requests
    private var etaCache: [String: (timeStamp: Date, travelTime: TimeInterval)] = [:]
    private let etaCacheValidityPeriod: TimeInterval = 900 // 15 minutes (increased)
    
    // Enhanced retry mechanism
    private var requestRetryCount: [String: Int] = [:]
    private let maxRetryAttempts = 5 // Increased retry attempts
    private var failedRequests: Set<String> = [] // Track completely failed requests
    
    // Background processing queue for better reliability
    private let backgroundQueue = DispatchQueue(label: "com.Levi.ToDoList.BackgroundProcessing", qos: .background)
    
    // Notification scheduling tracking
    private var notificationAttempts: [String: Int] = [:]
    private let maxNotificationAttempts = 3
    
    enum NetworkQuality {
        case excellent, good, fair, poor
    }
    
    init(userId: String? = nil) {
        self.userId = userId
        super.init()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        fetchUpcomingItems()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Request location permissions
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false // Changed to false for better reliability
        locationManager.activityType = .other
        locationManager.requestAlwaysAuthorization()
        
        // Get initial location
        requestSingleLocationUpdate()
        
        // Set up notification observers
        setupNotificationObservers()
    }
    
    // Setup notification observers for app lifecycle
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        // Attempt to complete critical operations before termination
        beginBackgroundTask()
        
        // Quick final check with current location
        if let userLocation = location {
            processLocationUpdateWithFallback(userLocation)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.endBackgroundTask()
        }
        
        endBackgroundTask()
    }
    
    // Enhanced network monitoring with quality assessment
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.hasConnectivity = path.status == .satisfied
                self?.isOnCellular = path.isExpensive
                
                // Assess network quality
                if path.status == .satisfied {
                    if path.isExpensive {
                        self?.networkQuality = path.availableInterfaces.first { $0.type == .cellular } != nil ? .fair : .good
                    } else {
                        self?.networkQuality = .excellent
                    }
                } else {
                    self?.networkQuality = .poor
                }
                
                print("Network status: \(path.status == .satisfied ? "Connected" : "Disconnected"), Quality: \(self?.networkQuality ?? .poor)")
                
                // If we regained connectivity, retry failed operations
                if path.status == .satisfied {
                    self?.retryFailedOperations()
                }
            }
        }
        
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    // Retry operations that previously failed
    private func retryFailedOperations() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Clear failed requests to allow retries
            self.failedRequests.removeAll()
            self.requestRetryCount.removeAll()
            
            // Wait a bit for network to stabilize
            Thread.sleep(forTimeInterval: 2.0)
            
            // If we have location, process items again
            if let userLocation = self.location {
                self.processLocationUpdateWithFallback(userLocation)
            } else {
                self.requestSingleLocationUpdate()
            }
        }
    }
    
    // Begin background task to prevent suspension
    private func beginBackgroundTask() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    // End background task
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    // Request a single location update with better error handling
    func requestSingleLocationUpdate() {
        guard CLLocationManager.authorizationStatus() == .authorizedAlways ||
              CLLocationManager.authorizationStatus() == .authorizedWhenInUse else {
            print("Location authorization not granted")
            return
        }
        
        // Create individual background task for this location request
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "LocationRequest") {
            print("Location request background task expired")
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
        
        locationManager.requestLocation()
        
        // Set a timeout for location request (reduced to 10 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }
    
    func updateUserId(_ newUserId: String) {
        self.userId = newUserId
        fetchUpcomingItems()
    }
    
    func clearUserId() {
        self.userId = nil
        fetchedItems = []
        // Clear caches
        etaCache.removeAll()
        requestRetryCount.removeAll()
        failedRequests.removeAll()
    }
    
    func fetchUpcomingItems() {
        self.checkUpcomingItemsForNotifications { items, error in
            if let error = error {
                print("Error fetching todos: \(error)")
                return
            } else if let items = items {
                print("Fetched \(items.count) todos in fetchUpcomingItems.")
                self.fetchedItems = items
            }
        }
    }
    
    // Handle authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        
        if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
            requestSingleLocationUpdate()
        }
    }
    
    // This function is called when the user's location is updated
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.location = location
            print("Location updated: \(location.coordinate)")
            
            // Process location update immediately
            processLocationUpdateWithFallback(location)
        }
        
        // End any pending background task from requestSingleLocationUpdate
        endBackgroundTask()
    }
    
    // Enhanced error handling for location failures
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        
        endBackgroundTask() // End any pending background task
        
        // Enhanced retry logic based on error type
        if let clError = error as? CLError {
            switch clError.code {
            case .network:
                // Network error - retry after longer delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.requestSingleLocationUpdate()
                }
            case .locationUnknown:
                // Location unknown - retry with shorter delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.requestSingleLocationUpdate()
                }
            case .denied:
                print("Location access denied")
                return
            default:
                // Other errors - standard retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.requestSingleLocationUpdate()
                }
            }
        }
    }
    
    // Clean up when deallocated
    deinit {
        stopBackgroundTimer()
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
    
    // Stop background updates
    func stopBackgroundTimer() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
    }
    
    // Handle app going to background
    func applicationDidEnterBackground() {
        beginBackgroundTask()
        stopBackgroundTimer()
        startBackgroundTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    // Enhanced background timer with adaptive intervals
    func startBackgroundTimer() {
        // Adjust interval based on network quality and device state
        var adjustedInterval = checkInterval
        
        switch networkQuality {
        case .excellent:
            adjustedInterval = checkInterval
        case .good:
            adjustedInterval = checkInterval * 1.2
        case .fair:
            adjustedInterval = checkInterval * 1.5
        case .poor:
            adjustedInterval = checkInterval * 2.0
        }
        
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: adjustedInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Begin background task for THIS specific timer fire
            var taskID: UIBackgroundTaskIdentifier = .invalid
            taskID = UIApplication.shared.beginBackgroundTask(withName: "TimerBackgroundTask") {
                // This expiration handler will be called if the task takes too long
                print("Background timer task expired")
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                }
            }
            
            // Skip update if no connectivity
            guard self.hasConnectivity else {
                print("Skipping background update - no connectivity")
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                }
                return
            }
            
            // Request location and process
            self.requestSingleLocationUpdate()
            
            // If we already have a location, process it immediately
            if let userLocation = self.location {
                self.processLocationUpdateWithFallback(userLocation)
            }
            
            // CRITICAL: End background task after processing (25 seconds max)
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                }
            }
        }
        
        // Fire immediately for the first check
        backgroundTimer?.fire()
    }
    
    // Enhanced location processing with fallback mechanisms
    func processLocationUpdateWithFallback(_ userLocation: CLLocation) {
        print("Processing location update with fallback mechanisms")
        
        fetchUpcomingItems()
        UserDefaults.standard.removeObject(forKey: "ScheduledNotifications")
        
        // Process with enhanced reliability
        processItemsWithEnhancedReliability(userLocation: userLocation)
    }
    
    // Enhanced processing with better reliability mechanisms
    private func processItemsWithEnhancedReliability(userLocation: CLLocation) {
        let itemsToProcess = fetchedItems.filter {
            !$0.isDone &&
            $0.dueDate > Date().timeIntervalSince1970 &&
            !$0.recentlyDeleted
        }
        
        // Sort by urgency (due date proximity)
        let sortedItems = itemsToProcess.sorted { $0.dueDate < $1.dueDate }
        
        print("Processing \(sortedItems.count) items with enhanced reliability")
        
        // Process items with adaptive batching
        processItemsBatchWithRetry(items: sortedItems, userLocation: userLocation, index: 0)
    }
    
    // Enhanced batch processing with retry mechanisms
    private func processItemsBatchWithRetry(items: [Item], userLocation: CLLocation, index: Int) {
        guard index < items.count else {
            print("Finished processing all \(items.count) items")
            return
        }
        
        // Adaptive batch size based on network quality
        let batchSize = getBatchSize()
        let end = min(index + batchSize, items.count)
        let currentBatch = Array(items[index..<end])
        
        print("Processing batch \(index/batchSize + 1): \(currentBatch.count) items")
        
        // Process each item in the current batch
        for item in currentBatch {
            checkItemForNotificationWithRetry(item, userLocation: userLocation)
        }
        
        // Adaptive delay between batches
        let batchDelay = getBatchDelay()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + batchDelay) { [weak self] in
            guard let self = self, self.hasConnectivity else { return }
            self.processItemsBatchWithRetry(items: items, userLocation: userLocation, index: end)
        }
    }
    
    // Get adaptive batch size based on network conditions
    private func getBatchSize() -> Int {
        switch networkQuality {
        case .excellent: return 8
        case .good: return 6
        case .fair: return 4
        case .poor: return 2
        }
    }
    
    // Get adaptive delay between batches
    private func getBatchDelay() -> Double {
        switch networkQuality {
        case .excellent: return 3.0
        case .good: return 5.0
        case .fair: return 8.0
        case .poor: return 12.0
        }
    }
    
    // Generate cache key with better precision
    private func cacheKeyForRoute(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, travelMode: Int) -> String {
        // Use higher precision for better cache accuracy
        let fromLat = round(userLocation.latitude * 1000) / 1000
        let fromLng = round(userLocation.longitude * 1000) / 1000
        let toLat = round(destination.latitude * 1000) / 1000
        let toLng = round(destination.longitude * 1000) / 1000
        
        return "\(fromLat),\(fromLng)-\(toLat),\(toLng)-\(travelMode)"
    }
    
    // Enhanced item checking with retry logic
    func checkItemForNotificationWithRetry(_ item: Item, userLocation: CLLocation) {
        guard let itemLatitude = item.latitude, let itemLongitude = item.longitude else {
            // No location - use default notification
            scheduleDefaultNotification(for: item)
            return
        }
        
        if itemLatitude != 0 && itemLongitude != 0 {
            let itemLocation = CLLocationCoordinate2D(latitude: itemLatitude, longitude: itemLongitude)
            
            calculateTravelTimeWithEnhancedRetry(from: userLocation.coordinate, to: itemLocation, gettingThere: item.gettingThere) { [weak self] travelTime in
                guard let self = self else { return }
                
                let finalTravelTime = travelTime ?? 3600
                let timeToLeave = Date(timeIntervalSince1970: item.dueDate).addingTimeInterval(-finalTravelTime)
                
                if Date() >= timeToLeave {
                    print("Time to leave for \(item.title)! Travel time: \(finalTravelTime)s")
                    self.scheduleNotificationWithRetry(for: item, at: timeToLeave)
                } else {
                    print("Not time yet for \(item.title). Time to leave: \(timeToLeave)")
                }
            }
        } else {
            scheduleDefaultNotification(for: item)
        }
    }
    
    // Schedule default notification (1 hour before)
    private func scheduleDefaultNotification(for item: Item) {
        let timeToLeave = Date(timeIntervalSince1970: item.dueDate).addingTimeInterval(-3600)
        if Date() >= timeToLeave {
            scheduleNotificationWithRetry(for: item, at: timeToLeave)
        }
    }
    
    // Legacy method for compatibility
    func checkItemForNotification(_ item: Item, userLocation: CLLocation) {
        checkItemForNotificationWithRetry(item, userLocation: userLocation)
    }
    
    func checkUpcomingItemsForNotifications(completion: @escaping ([Item]?, Error?) -> Void) {
        guard let userId = userId else {
            completion(nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is nil"]))
            return
        }
        
        guard hasConnectivity else {
            print("Skipping items fetch - no connectivity")
            completion(nil, NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "No network connectivity"]))
            return
        }
        
        let db = Firestore.firestore()
        let todosRef = db.collection("users").document(userId).collection("todos")
        
        // Adaptive timeout based on network quality
        let timeout: TimeInterval = getNetworkTimeout()
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        var timeoutOccurred = false
        var fetchedTodos: [Item]?
        var fetchError: Error?
        
        // Timeout handler
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if dispatchGroup.wait(timeout: .now()) == .timedOut {
                timeoutOccurred = true
                fetchError = NSError(domain: "", code: -3, userInfo: [NSLocalizedDescriptionKey: "Firestore fetch timed out"])
                dispatchGroup.leave()
            }
        }
        
        todosRef.getDocuments { snapshot, error in
            guard !timeoutOccurred else { return }
            
            if let error = error {
                fetchError = error
            } else if let snapshot = snapshot {
                do {
                    fetchedTodos = try snapshot.documents.compactMap { document -> Item? in
                        try document.data(as: Item.self)
                    }
                } catch {
                    print("Error decoding items: \(error.localizedDescription)")
                    // Manual decoding fallback
                    fetchedTodos = snapshot.documents.compactMap { document -> Item? in
                        let data = document.data()
                        guard
                            let id = data["id"] as? String,
                            let title = data["title"] as? String,
                            let dueDate = data["dueDate"] as? TimeInterval,
                            let tagName = data["tagName"] as? String,
                            let tagColorIndex = data["tagColorIndex"] as? Int,
                            let createdDate = data["createdDate"] as? TimeInterval,
                            let isDone = data["isDone"] as? Bool,
                            let recentlyDeleted = data["recentlyDeleted"] as? Bool
                        else { return nil }
                        
                        let streaked = data["streaked"] as? Bool ?? false
                        let encryptedLatitude = data["encryptedLatitude"] as? String
                        let encryptedLongitude = data["encryptedLongitude"] as? String
                        let encryptedLocationDescription = data["encryptedLocationDescription"] as? String ?? ""
                        let gettingThere = data["gettingThere"] as? Int ?? 0
                        
                        return Item(
                            id: id,
                            title: title,
                            dueDate: dueDate,
                            tagName: tagName,
                            tagColorIndex: tagColorIndex,
                            createdDate: createdDate,
                            isDone: isDone,
                            recentlyDeleted: recentlyDeleted,
                            streaked: streaked,
                            latitude: encryptedLatitude != nil ? EncryptionService.decryptToDouble(encryptedLatitude!) : nil,
                            longitude: encryptedLongitude != nil ? EncryptionService.decryptToDouble(encryptedLongitude!) : nil,
                            locationDescription: EncryptionService.decrypt(encryptedLocationDescription) ?? "no location information",
                            gettingThere: gettingThere
                        )
                    }
                }
            }
            
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(fetchedTodos, fetchError)
        }
    }
    
    // Get adaptive timeout based on network quality
    private func getNetworkTimeout() -> TimeInterval {
        switch networkQuality {
        case .excellent: return 10
        case .good: return 15
        case .fair: return 25
        case .poor: return 40
        }
    }
    
    // Enhanced travel time calculation with comprehensive retry logic
    func calculateTravelTimeWithEnhancedRetry(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, gettingThere: Int, completion: @escaping (TimeInterval?) -> Void) {
        
        let cacheKey = cacheKeyForRoute(from: userLocation, to: destination, travelMode: gettingThere)
        
        // Check if this request has completely failed before
        if failedRequests.contains(cacheKey) {
            print("Request previously failed completely - using estimation")
            let estimatedTime = estimateTravelTime(from: userLocation, to: destination, transportType: gettingThere)
            completion(estimatedTime)
            return
        }
        
        // Check cache first
        if let cachedResult = etaCache[cacheKey],
           Date().timeIntervalSince(cachedResult.timeStamp) < etaCacheValidityPeriod {
            print("Using cached travel time: \(cachedResult.travelTime)s")
            completion(cachedResult.travelTime)
            return
        }
        
        // Skip if no connectivity
        guard hasConnectivity else {
            print("No connectivity - using estimation")
            let estimatedTime = estimateTravelTime(from: userLocation, to: destination, transportType: gettingThere)
            completion(estimatedTime)
            return
        }
        
        // Enhanced queue management
        LocationManager.etaRequestQueue.async { [weak self] in
            guard let self = self else { return }
            
            // More conservative request limiting
            let maxAllowedRequests = self.getMaxAllowedRequests()
            
            if LocationManager.pendingETARequests >= maxAllowedRequests {
                print("Too many pending requests (\(LocationManager.pendingETARequests)) - using estimation")
                let estimatedTime = self.estimateTravelTime(from: userLocation, to: destination, transportType: gettingThere)
                DispatchQueue.main.async {
                    completion(estimatedTime)
                }
                return
            }
            
            // Execute request with enhanced error handling
            self.executeETARequest(from: userLocation, to: destination, gettingThere: gettingThere, cacheKey: cacheKey, completion: completion)
        }
    }
    
    // Get maximum allowed concurrent requests based on network quality
    private func getMaxAllowedRequests() -> Int {
        switch networkQuality {
        case .excellent: return 5
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        }
    }
    
    // Execute ETA request with comprehensive error handling
    private func executeETARequest(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, gettingThere: Int, cacheKey: String, completion: @escaping (TimeInterval?) -> Void) {
        
        LocationManager.pendingETARequests += 1
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = (gettingThere == 0) ? .walking : .automobile
        request.requestsAlternateRoutes = false // Reduce complexity
        
        let directions = MKDirections(request: request)
        let currentRetryCount = requestRetryCount[cacheKey] ?? 0
        requestRetryCount[cacheKey] = currentRetryCount + 1
        
        print("ETA request attempt \(currentRetryCount + 1)/\(maxRetryAttempts) for route \(cacheKey)")
        
        directions.calculateETA { [weak self] response, error in
            guard let self = self else { return }
            
            // Always decrement counter
            LocationManager.etaRequestQueue.async {
                LocationManager.pendingETARequests -= 1
            }
            
            if let error = error {
                print("ETA calculation error: \(error.localizedDescription)")
                self.handleETAError(error: error, cacheKey: cacheKey, from: userLocation, to: destination, gettingThere: gettingThere, completion: completion)
            } else if let travelTime = response?.expectedTravelTime {
                // Success - cache and return
                self.etaCache[cacheKey] = (Date(), travelTime)
                self.requestRetryCount[cacheKey] = 0 // Reset retry count
                
                print("✓ Got ETA: \(travelTime)s for route \(cacheKey)")
                DispatchQueue.main.async {
                    completion(travelTime)
                }
            } else {
                // No travel time in response
                print("No travel time in response for route \(cacheKey)")
                let estimatedTime = self.estimateTravelTime(from: userLocation, to: destination, transportType: gettingThere)
                DispatchQueue.main.async {
                    completion(estimatedTime)
                }
            }
        }
    }
    
    // Enhanced error handling for ETA requests
    private func handleETAError(error: Error, cacheKey: String, from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, gettingThere: Int, completion: @escaping (TimeInterval?) -> Void) {
        
        let currentRetryCount = requestRetryCount[cacheKey] ?? 0
        
        // Check if we should retry
        if currentRetryCount < maxRetryAttempts && hasConnectivity {
            // Calculate progressive backoff delay
            let baseDelay: Double = networkQuality == .poor ? 3.0 : 1.5
            let retryDelay = baseDelay * pow(2.0, Double(currentRetryCount - 1))
            
            print("Retrying ETA request in \(retryDelay)s (attempt \(currentRetryCount + 1)/\(maxRetryAttempts))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                self?.calculateTravelTimeWithEnhancedRetry(from: userLocation, to: destination, gettingThere: gettingThere, completion: completion)
            }
        } else {
            // Max retries reached or no connectivity
            print("Max retries reached for route \(cacheKey) - marking as failed")
            failedRequests.insert(cacheKey)
            
            let estimatedTime = estimateTravelTime(from: userLocation, to: destination, transportType: gettingThere)
            DispatchQueue.main.async {
                completion(estimatedTime)
            }
        }
    }
    
    // Legacy method for compatibility
    func calculateTravelTime(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, gettingThere: Int, completion: @escaping (TimeInterval?) -> Void) {
        calculateTravelTimeWithEnhancedRetry(from: userLocation, to: destination, gettingThere: gettingThere, completion: completion)
    }
    
    // Improved estimation with better accuracy
    private func estimateTravelTime(from userLocation: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: Int) -> TimeInterval {
        let sourceLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        let distance = sourceLocation.distance(from: destLocation)
        
        // More realistic speed estimates
        let estimatedSpeed: Double
        if transportType == 0 { // Walking
            estimatedSpeed = 1.2 // 4.3 km/h
        } else { // Driving
            // Adjust speed based on distance (city vs highway)
            if distance < 5000 { // Less than 5km - city driving
                estimatedSpeed = 8.3 // 30 km/h
            } else { // Longer distance - mixed driving
                estimatedSpeed = 13.9 // 50 km/h
            }
        }
        
        // Adaptive buffer based on network quality and time estimation uncertainty
        let bufferMultiplier: Double
        switch networkQuality {
        case .excellent: bufferMultiplier = 1.2
        case .good: bufferMultiplier = 1.3
        case .fair: bufferMultiplier = 1.4
        case .poor: bufferMultiplier = 1.6
        }
        
        let estimatedTime = (distance / estimatedSpeed) * bufferMultiplier
        print("Estimated travel time: \(estimatedTime)s for \(distance)m distance")
        
        return estimatedTime
    }
    
    // Enhanced notification scheduling with retry logic
    func scheduleNotificationWithRetry(for item: Item, at triggerDate: Date) {
        let attempts = notificationAttempts[item.id] ?? 0
        
        if attempts >= maxNotificationAttempts {
            print("Max notification attempts reached for: \(item.title)")
            return
        }
        
        // Check if already scheduled
        var scheduledNotifications = UserDefaults.standard.array(forKey: "ScheduledNotifications") as? [String] ?? []
        
        if scheduledNotifications.contains(item.id) {
            print("Notification already scheduled for: \(item.title)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Task Due"
        content.body = "You shall get ready for your task, '\(item.title)'."
        content.sound = .default
        content.categoryIdentifier = "TASK_REMINDER"
        
        content.userInfo = [
            "itemId": item.id,
            "title": item.title,
            "dueDate": item.dueDate
        ]
        
        // For production, use actual trigger time
        // For testing, use 10 seconds from now
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date().addingTimeInterval(10)),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
        
        // Increment attempt counter
        notificationAttempts[item.id] = attempts + 1
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
                
                // Retry scheduling after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.scheduleNotificationWithRetry(for: item, at: triggerDate)
                }
            } else {
                print("✓ Successfully scheduled notification for: \(item.title)")
                
                // Reset attempt counter on success
                self?.notificationAttempts[item.id] = 0
                
                // Add to scheduled notifications list
                scheduledNotifications.append(item.id)
                UserDefaults.standard.set(scheduledNotifications, forKey: "ScheduledNotifications")
                
                // Verify the notification was actually scheduled
                self?.verifyNotificationScheduled(for: item)
            }
        }
    }
    
    // Verify that a notification was actually scheduled
    private func verifyNotificationScheduled(for item: Item) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let found = requests.contains { $0.identifier == item.id }
                print("Verification: Notification for \(item.title) is \(found ? "✓ scheduled" : "✗ NOT found")")
                
                if !found {
                    print("Warning: Notification verification failed - attempting to reschedule")
                    // Attempt to reschedule if verification fails
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.scheduleNotificationWithRetry(for: item, at: Date())
                    }
                }
            }
        }
    }
    
    // Legacy method for compatibility
    func scheduleNotification(for item: Item, at triggerDate: Date) {
        scheduleNotificationWithRetry(for: item, at: triggerDate)
    }

    // Enhanced foreground handling
    func applicationDidEnterForeground() {
        print("App entered foreground - refreshing location and notifications")
        
        stopBackgroundTimer()
        
        // Clear failed requests to allow fresh attempts
        failedRequests.removeAll()
        requestRetryCount.removeAll()
        
        // Request fresh location
        requestSingleLocationUpdate()
        
        // Process with current location if available
        if let userLocation = self.location {
            processLocationUpdateWithFallback(userLocation)
        }
        
        // Verify and fix any missing notifications
        verifyAndFixNotifications()
    }
    
    // Comprehensive notification verification and repair
    private func verifyAndFixNotifications() {
        let scheduledIds = UserDefaults.standard.array(forKey: "ScheduledNotifications") as? [String] ?? []
        
        guard !scheduledIds.isEmpty else { return }
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            let pendingIds = Set(requests.map { $0.identifier })
            let expectedIds = Set(scheduledIds)
            let missingIds = expectedIds.subtracting(pendingIds)
            
            if !missingIds.isEmpty {
                print("Found \(missingIds.count) missing notifications - attempting to reschedule")
                
                // Clear the missing IDs from UserDefaults
                let remainingIds = scheduledIds.filter { !missingIds.contains($0) }
                UserDefaults.standard.set(remainingIds, forKey: "ScheduledNotifications")
                
                // Attempt to reschedule missing notifications
                if let userLocation = self.location {
                    for itemId in missingIds {
                        if let item = self.fetchedItems.first(where: { $0.id == itemId && !$0.isDone && !$0.recentlyDeleted }) {
                            print("Rescheduling missing notification for: \(item.title)")
                            self.checkItemForNotificationWithRetry(item, userLocation: userLocation)
                        }
                    }
                }
            } else {
                print("✓ All scheduled notifications are present")
            }
        }
    }
    
    // Get the latest location with retry
    func getLatestLocation() -> CLLocation? {
        if location == nil {
            requestSingleLocationUpdate()
        }
        return location
    }
    
    // Enhanced debug method
    func forceNotificationForItem(withId itemId: String) {
        guard let item = fetchedItems.first(where: { $0.id == itemId }) else {
            print("Item not found with ID: \(itemId)")
            return
        }
        
        // Clear any previous attempts
        notificationAttempts[item.id] = 0
        
        scheduleNotificationWithRetry(for: item, at: Date())
        print("✓ Forced notification scheduled for item: \(item.title)")
    }
    
    // Additional utility methods for debugging and monitoring
    
    // Get current system status
    func getSystemStatus() -> [String: Any] {
        return [
            "hasConnectivity": hasConnectivity,
            "networkQuality": String(describing: networkQuality),
            "isOnCellular": isOnCellular,
            "pendingETARequests": LocationManager.pendingETARequests,
            "cachedRoutes": etaCache.count,
            "failedRoutes": failedRequests.count,
            "locationAvailable": location != nil,
            "backgroundTaskActive": backgroundTaskIdentifier != .invalid,
            "fetchedItemsCount": fetchedItems.count
        ]
    }
    
    // Clear all caches and reset state
    func resetAllCaches() {
        print("Resetting all caches and state")
        
        etaCache.removeAll()
        requestRetryCount.removeAll()
        failedRequests.removeAll()
        notificationAttempts.removeAll()
        
        // Clear scheduled notifications
        UserDefaults.standard.removeObject(forKey: "ScheduledNotifications")
        
        // Cancel all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        print("✓ All caches and state reset")
    }
    
    // Force a complete refresh cycle
    func forceCompleteRefresh() {
        print("Starting complete refresh cycle")
        
        beginBackgroundTask()
        
        // Reset state
        resetAllCaches()
        
        // Get fresh location
        requestSingleLocationUpdate()
        
        // Fetch fresh items
        fetchUpcomingItems()
        
        // Process after a short delay to allow for data fetching
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            
            if let userLocation = self.location {
                self.processLocationUpdateWithFallback(userLocation)
            }
            
            self.endBackgroundTask()
        }
        
        print("✓ Complete refresh cycle initiated")
    }
}
