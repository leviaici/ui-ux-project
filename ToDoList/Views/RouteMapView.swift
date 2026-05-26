//
//  RouteMapView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 13.05.2025.
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    let item: Item
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()
    
    @State private var routes: [MKRoute] = []
    @State private var selectedRouteIndex: Int = 0
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var retryCount = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Max retry attempts for location and route
    private let maxLocationAttempts = 20
    private let maxRouteAttempts = 3
    
    // Computed property to get the currently selected route
    private var selectedRoute: MKRoute? {
        guard !routes.isEmpty, selectedRouteIndex < routes.count else { return nil }
        return routes[selectedRouteIndex]
    }
    
    // Colors for different routes
    private let routeColors: [Color] = [.blue, .green, .orange, .purple, .pink]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Map View
                MapViewRepresentable(routes: routes, selectedRouteIndex: selectedRouteIndex, region: $region, routeColors: routeColors)
                    .ignoresSafeArea(edges: .top)
                
                // Bottom sheet with route info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.gray)
                                .font(.title3)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        Text("Route to Destination")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            retryCount = 0
                            calculateRoute()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                                .font(.title3)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                    .padding()
                                
                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                            Spacer()
                        }
                    } else if let errorMessage = errorMessage, routes.isEmpty {
                        VStack(spacing: 12) {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            // Fall back to destination-only view if we have coordinates
                            if let latitude = item.latitude, let longitude = item.longitude, latitude != 0, longitude != 0 {
                                Button(action: {
                                    showDestinationOnly()
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("Show Destination Only")
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    } else {
                        // Route details
                        VStack(alignment: .leading, spacing: 16) {
                            // From
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading) {
                                    Text("From")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("Your Location")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal)
                            
                            // To
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading) {
                                    Text("To")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(item.locationDescription)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Transport method
                            HStack(spacing: 12) {
                                Image(systemName: item.gettingThere == 0 ? "figure.walk" : "car.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 28, height: 28)
                                
                                VStack(alignment: .leading) {
                                    Text("Transport")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(item.gettingThere == 0 ? "Walking" : "Driving")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Available routes
                            if !routes.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(0..<routes.count, id: \.self) { index in
                                            let route = routes[index]
                                            Button(action: {
                                                selectedRouteIndex = index
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Circle()
                                                            .fill(routeColors[index % routeColors.count])
                                                            .frame(width: 8, height: 8)
                                                        
                                                        Text("Route \(index + 1)")
                                                            .font(.caption)
                                                            .fontWeight(index == selectedRouteIndex ? .bold : .regular)
                                                        
                                                        if index == 0 {
                                                            Text("(fastest)")
                                                                .font(.caption)
                                                                .foregroundColor(.green)
                                                        }
                                                    }
                                                    
                                                    Text(formatTimeInterval(route.expectedTravelTime))
                                                        .font(.caption)
                                                        .fontWeight(index == selectedRouteIndex ? .bold : .regular)
                                                    
                                                    Text(formatDistance(route.distance))
                                                        .font(.caption)
                                                        .fontWeight(index == selectedRouteIndex ? .bold : .regular)
                                                }
                                                .padding(8)
                                                .background(index == selectedRouteIndex ? Color.gray.opacity(0.2) : Color.clear)
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(height: 80)
                                
                                // Route info
                                if let selectedRoute = selectedRoute {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.orange)
                                            .frame(width: 28, height: 28)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Estimated Time")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(formatTimeInterval(selectedRoute.expectedTravelTime))
                                                .font(.subheadline)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text("Distance")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(formatDistance(selectedRoute.distance))
                                                .font(.subheadline)
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    // Open in Maps button
                                    Button(action: {
                                        openInMaps()
                                    }) {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "map.fill")
                                            Text("Open in Maps")
                                                .fontWeight(.medium)
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .background(Color.appColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -5)
                .frame(height: 380)
            }
        }
        .onAppear {
            // Set up an observation of the location property
            setupLocationObserver()
        }
    }
    
    // Set up location observation
    private func setupLocationObserver() {
        isLoading = true
        errorMessage = "Getting your location..."
        
        // Check if we have location permission first
        checkPermissionAndProceed()
    }
    
    // Check location permissions before proceeding
    private func checkPermissionAndProceed() {
        let status = CLLocationManager().authorizationStatus
        
        switch status {
        case .notDetermined:
            errorMessage = "Location permission needed"
            locationManager.requestSingleLocationUpdate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                checkPermissionAndProceed()
            }
        case .restricted, .denied:
            isLoading = false
            errorMessage = "Location access denied. Please enable location permissions in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            // Request location
            locationManager.requestSingleLocationUpdate()
            
            // Wait for location using a timer
            checkForLocationAndCalculateRoute()
        @unknown default:
            isLoading = false
            errorMessage = "Unknown location permission status"
        }
    }
    
    // Recursively check for location with a timeout
    private func checkForLocationAndCalculateRoute(attempt: Int = 0) {
        if let _ = locationManager.location {
            // We have a location, calculate route
            calculateRoute()
        } else if attempt < maxLocationAttempts {
            // Still waiting for location, check again in 0.5 seconds
            if attempt % 4 == 0 { // Update message every 2 seconds
                errorMessage = "Getting your location... \(attempt/2)s"
                
                // Try requesting location again on cellular networks
                locationManager.requestSingleLocationUpdate()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkForLocationAndCalculateRoute(attempt: attempt + 1)
            }
        } else {
            // Timeout - no location received
            isLoading = false
            errorMessage = "Unable to access your location. Please check your location permissions and network connection."
        }
    }
    
    // Calculate route from current location to destination
    private func calculateRoute(attempt: Int = 0) {
        guard let latitude = item.latitude, let longitude = item.longitude, latitude != 0, longitude != 0 else {
            errorMessage = "Invalid destination coordinates"
            isLoading = false
            return
        }
        
        guard let userLocation = locationManager.location?.coordinate else {
            errorMessage = "Unable to access your current location"
            isLoading = false
            return
        }
        
        // Only clear message if this is the first attempt
        if attempt == 0 {
            // Clear previous routes and error
            routes = []
            errorMessage = "Calculating routes..."
            isLoading = true
        }
        
        // Set the region to include both points
        region = getRegionForCoordinates(userLocation, CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        
        // Create the route request
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        request.transportType = item.gettingThere == 0 ? .walking : .automobile
        request.requestsAlternateRoutes = true // Request multiple routes
        
        // Calculate the route
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                // If this is not our last retry attempt, try again
                if attempt < self.maxRouteAttempts - 1 {
                    self.retryCount = attempt + 1
                    self.errorMessage = "Retrying route calculation... (\(attempt + 1)/\(self.maxRouteAttempts))"
                    
                    // Wait before retrying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.calculateRoute(attempt: attempt + 1)
                    }
                    return
                }
                
                self.isLoading = false
                self.errorMessage = "Error calculating route: \(error.localizedDescription). Please check your network connection."
                return
            }
            
            if let response = response, !response.routes.isEmpty {
                self.isLoading = false
                self.errorMessage = nil
                
                // Sort routes by travel time (fastest first)
                self.routes = response.routes.sorted(by: { $0.expectedTravelTime < $1.expectedTravelTime })
                
                // Select fastest route by default
                self.selectedRouteIndex = 0
                
                // Adjust the region to show all routes
                if let fastestRoute = self.routes.first {
                    let padding = 1.1 // Add a bit of padding
                    let rect = fastestRoute.polyline.boundingMapRect
                    let adjustedRect = MKMapRect(
                        x: rect.origin.x - rect.size.width * (padding - 1) / 2,
                        y: rect.origin.y - rect.size.height * (padding - 1) / 2,
                        width: rect.size.width * padding,
                        height: rect.size.height * padding
                    )
                    
                    // Use MKMapRect to set the region
                    let region = MKCoordinateRegion(adjustedRect)
                    self.region = region
                }
            } else {
                // If this is not our last retry attempt, try again
                if attempt < self.maxRouteAttempts - 1 {
                    self.retryCount = attempt + 1
                    self.errorMessage = "Retrying route calculation... (\(attempt + 1)/\(self.maxRouteAttempts))"
                    
                    // Wait before retrying
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.calculateRoute(attempt: attempt + 1)
                    }
                } else {
                    self.isLoading = false
                    self.errorMessage = "No routes found. Please try again or check your network connection."
                }
            }
        }
    }
    
    // Fallback to show just the destination when route calculation fails
    private func showDestinationOnly() {
        if let latitude = item.latitude, let longitude = item.longitude {
            let destination = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            region = MKCoordinateRegion(
                center: destination,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            
            // Create a pin annotation for destination
            errorMessage = nil
            isLoading = false
        }
    }
    
    // Open in native Maps app
    private func openInMaps() {
        if let latitude = item.latitude, let longitude = item.longitude {
            let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
            destination.name = item.title
            
            // Set the route type based on the transport mode
            let launchOptions = [
                MKLaunchOptionsDirectionsModeKey: item.gettingThere == 0 ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
            ]
            
            destination.openInMaps(launchOptions: launchOptions)
        }
    }
    
    // Format time interval to human-readable string
    private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: timeInterval) ?? "Unknown"
    }
    
    // Format distance to human-readable string
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        
        return formatter.string(fromDistance: distance)
    }
    
    // Calculate a region that contains both source and destination
    private func getRegionForCoordinates(_ source: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: (source.latitude + destination.latitude) / 2,
            longitude: (source.longitude + destination.longitude) / 2
        )
        
        let latDelta = abs(source.latitude - destination.latitude) * 1.5
        let lonDelta = abs(source.longitude - destination.longitude) * 1.5
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.01), longitudeDelta: max(lonDelta, 0.01))
        )
    }
}

// Extension to add rounded corners to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
