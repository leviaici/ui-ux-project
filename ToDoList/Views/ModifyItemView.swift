//
//  ModifyItemView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 07.09.2023.
//

import SwiftUI
import MapKit

struct ModifyItemView: View {
    @StateObject private var viewModel: ModifyItemViewViewModel
    @Binding var modifiedItemPresented: Bool

    var existingTags: [String]
    var tagColorMap: [String: Int]

    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isMapVisible: Bool = false
    @State private var showsUserLocation: Bool = false
    @State private var nearestAttraction: String?
    @State private var isWalking: Bool = true

    @State private var mapView: MKMapView?

    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    @State private var showSearchResults: Bool = false

    @Binding private var toBeCopied: Bool

    @State private var selectedTag: String
    @State private var showCustomTagSheet: Bool = false
    @State private var newTagName: String = ""
    @State private var newTagColor: Color = .blue

    private let defaultTags = ["Work", "School", "Family", "Personal"]
    @State private var tags: [String]
    @State private var tagColors: [String: Color] = [:]

    private let colorOptions: [Color] = [
        .blue, .red, .green, .purple, .orange,
        .pink, .yellow, .indigo, .cyan, .brown
    ]

    @State private var shouldCenterMap: Bool = false

    private var pins: [MKPointAnnotation] {
        if let location = selectedLocation {
            let pin = MKPointAnnotation()
            pin.coordinate = location
            pin.title = "Selected Location"
            return [pin]
        }
        return []
    }

    init(item: Item, modifiedItemPresented: Binding<Bool>, toBeCopied: Binding<Bool>, existingTags: [String] = [], tagColorMap: [String: Int] = [:]) {
        _viewModel = StateObject(wrappedValue: ModifyItemViewViewModel(item: item))
        _modifiedItemPresented = modifiedItemPresented
        _toBeCopied = toBeCopied
        self.existingTags = existingTags
        self.tagColorMap = tagColorMap
        _selectedTag = State(initialValue: item.tagName)
        _tags = State(initialValue: [])
        _tagColors = State(initialValue: [:])
    }

    var body: some View {
        VStack {
            Text(toBeCopied ? "Copy Item" : "Edit Item")
                .font(.system(size: 32))
                .bold()
                .padding(.top, 30)

            Form {
                TextField("Title", text: $viewModel.title)
                    .textFieldStyle(DefaultTextFieldStyle())

                DatePicker("Due Date", selection: $viewModel.dueDate)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .listRowSeparator(.hidden)

                // Tags section
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            let tagColor = tagColors[tag, default: .gray]
                            Text(tag)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedTag == tag ? tagColor : Color.gray.opacity(0.3))
                                .cornerRadius(8)
                                .foregroundColor(.primary)
                                .onTapGesture {
                                    viewModel.selectedTag = tag
                                    if let colorIndex = colorOptions.firstIndex(of: tagColor) {
                                        viewModel.tagColorIndex = colorIndex
                                    }
                                    selectedTag = tag
                                }
                        }

                        Button(action: { showCustomTagSheet = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.primary)
                                .padding(5)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .listRowSeparator(.hidden)
                .frame(height: 40)
                .sheet(isPresented: $showCustomTagSheet) {
                    Form {
                        Section(header: Text("Create Custom Tag")) {
                            TextField("Tag Name", text: $newTagName)
                                .autocorrectionDisabled()
                        }

                        Section(header: Text("Choose a Color")) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 15) {
                                ForEach(colorOptions, id: \.self) { color in
                                    ZStack {
                                        Circle().fill(color).frame(width: 50, height: 50)
                                        if newTagColor == color {
                                            Circle().stroke(Color.primary, lineWidth: 1).frame(width: 50, height: 50)
                                        }
                                    }
                                    .onTapGesture { newTagColor = color }
                                }
                            }
                            .padding(.vertical)
                        }

                        Section {
                            TLButton(title: "Add Tag", background: newTagName.isEmpty ? .gray : .appColor) {
                                if !newTagName.isEmpty {
                                    tags.append(newTagName)
                                    tagColors[newTagName] = newTagColor
                                    if let colorIndex = colorOptions.firstIndex(of: newTagColor) {
                                        tagColors[newTagName] = newTagColor
                                        viewModel.selectedTag = newTagName
                                        viewModel.tagColorIndex = colorIndex
                                    }
                                    selectedTag = newTagName
                                    showCustomTagSheet = false
                                    newTagName = ""
                                    newTagColor = .blue
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .disabled(newTagName.isEmpty)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }

                // ── Location section — adults only ──────────────────────────
                if viewModel.isAdult {
                    Button(action: {
                        withAnimation {
                            isMapVisible.toggle()
                            showsUserLocation = isMapVisible
                            if !isMapVisible { showSearchResults = false }
                        }
                    }) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse").foregroundColor(.red)
                            Text("Location").font(.headline)
                            Spacer()
                            if let attraction = nearestAttraction, !attraction.isEmpty {
                                Text(attraction)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Image(systemName: isMapVisible ? "chevron.up" : "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowSeparator(.hidden)

                    if isMapVisible {
                        ZStack(alignment: .top) {
                            MapView(
                                mapType: .standard,
                                animated: true,
                                altitude: 1500,
                                currentPin: selectedLocation.map { coord -> MKPointAnnotation in
                                    let pin = MKPointAnnotation()
                                    pin.coordinate = coord
                                    pin.title = "Selected Location"
                                    return pin
                                },
                                startLocation: selectedLocation,
                                showsUserLocation: showsUserLocation
                            ) { coordinate in
                                selectedLocation = coordinate
                                viewModel.latitude = coordinate.latitude
                                viewModel.longitude = coordinate.longitude
                                getNearestLocation(from: coordinate) { attractionName in
                                    nearestAttraction = attractionName
                                    viewModel.locationDescription = attractionName.map { "near \($0)" } ?? "no location information"
                                }
                            } onPinAdded: { coordinate in
                                selectedLocation = coordinate
                                viewModel.latitude = coordinate.latitude
                                viewModel.longitude = coordinate.longitude
                                getNearestLocation(from: coordinate) { attractionName in
                                    nearestAttraction = attractionName
                                    viewModel.locationDescription = attractionName.map { "near \($0)" } ?? "no location information"
                                }
                            }
                            .frame(height: 350)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                            .transition(.opacity)
                            .onChange(of: shouldCenterMap) { _ in
                                if shouldCenterMap { shouldCenterMap = false }
                            }
                            .offset(y: 0)

                            // Search bar overlay
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    HStack {
                                        Image(systemName: "magnifyingglass").foregroundColor(.gray).padding(10)
                                        TextField("Search for location", text: $searchText)
                                            .autocorrectionDisabled()
                                            .onSubmit { searchLocation() }
                                            .onChange(of: searchText) { newText in
                                                if newText.isEmpty {
                                                    searchResults = []
                                                    showSearchResults = false
                                                } else if newText.count >= 2 {
                                                    searchLocation()
                                                }
                                            }
                                        if !searchText.isEmpty {
                                            Button(action: {
                                                searchText = ""
                                                searchResults = []
                                                showSearchResults = false
                                            }) {
                                                Image(systemName: "xmark.circle").foregroundColor(.gray).padding(10)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)

                                    if showSearchResults && !searchResults.isEmpty {
                                        Divider()
                                        if searchResults.count <= 3 {
                                            ForEach(searchResults, id: \.self) { item in
                                                SearchResultRowTransparent(item: item) { selectSearchResult(item) }
                                                    .frame(minHeight: 60)
                                                if item != searchResults.last { Divider() }
                                            }
                                        } else {
                                            ScrollView {
                                                VStack(spacing: 0) {
                                                    ForEach(searchResults, id: \.self) { item in
                                                        SearchResultRowTransparent(item: item) { selectSearchResult(item) }
                                                            .frame(minHeight: 60)
                                                        if item != searchResults.last { Divider() }
                                                    }
                                                }
                                            }
                                            .frame(maxHeight: 200)
                                        }
                                    }
                                }
                                .background(Color(.systemBackground).opacity(0.9))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                        }
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)

                        if let location = nearestAttraction {
                            HStack {
                                Image(systemName: "mappin").foregroundColor(.red)
                                Text(location).font(.subheadline).foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                        }

                        Toggle(isOn: $isWalking) {
                            Text(isWalking ? "Getting there: by foot" : "Getting there: by car")
                                .font(.headline)
                        }
                        .toggleStyle(ToggleButton())
                        .onChange(of: isWalking) { newValue in
                            viewModel.gettingThere = newValue ? 0 : 1
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                // ── End location section ─────────────────────────────────────

                if !toBeCopied {
                    TLButton(title: "Edit", background: .appColor) {
                        if viewModel.canModify {
                            viewModel.modify()
                            modifiedItemPresented = false
                        } else {
                            viewModel.showAlert = true
                        }
                    }
                } else {
                    TLButton(title: "Copy", background: .appColor) {
                        if viewModel.canModify {
                            viewModel.copy()
                            modifiedItemPresented = false
                        } else {
                            viewModel.showAlert = true
                        }
                    }
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text("Please ensure all fields are filled and the due date is later than today.")
                )
            }
        }
        .onAppear {
            setupTagsAndColors()
            isWalking = viewModel.gettingThere == 0

            if let latitude = viewModel.latitude, let longitude = viewModel.longitude,
               latitude != 0, longitude != 0 {
                selectedLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                updateNearestLocation()
            }
        }
        .onChange(of: viewModel.gettingThere) { newValue in
            isWalking = newValue == 0
        }
    }

    // MARK: - Private helpers

    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        MKLocalSearch(request: searchRequest).start { response, error in
            isSearching = false
            if let error = error {
                print("Error searching for locations: \(error.localizedDescription)")
                return
            }
            if let response = response {
                searchResults = response.mapItems
                showSearchResults = !searchResults.isEmpty
            }
        }
    }

    private func selectSearchResult(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        selectedLocation = coordinate
        viewModel.latitude = coordinate.latitude
        viewModel.longitude = coordinate.longitude

        getNearestLocation(from: coordinate) { attractionName in
            nearestAttraction = attractionName
            viewModel.locationDescription = nearestAttraction.map { "near \($0)" } ?? "no location information"
        }

        searchText = ""
        showSearchResults = false
        withAnimation {
            isMapVisible = true
            showsUserLocation = true
            shouldCenterMap = true
        }
    }

    private func setupTagsAndColors() {
        var allTags = defaultTags
        var allTagColors: [String: Color] = [
            "Work": .blue, "School": .green, "Family": .red, "Personal": .purple
        ]

        for tag in existingTags where !allTags.contains(tag) {
            allTags.append(tag)
            if let colorIndex = tagColorMap[tag], colorIndex >= 0, colorIndex < colorOptions.count {
                allTagColors[tag] = colorOptions[colorIndex]
            } else {
                allTagColors[tag] = .blue
            }
        }

        if !allTags.contains(viewModel.selectedTag) {
            allTags.append(viewModel.selectedTag)
            if viewModel.tagColorIndex >= 0, viewModel.tagColorIndex < colorOptions.count {
                allTagColors[viewModel.selectedTag] = colorOptions[viewModel.tagColorIndex]
            } else {
                allTagColors[viewModel.selectedTag] = .blue
            }
        }

        self.tags = allTags
        self.tagColors = allTagColors
    }

    private func updateNearestLocation() {
        if let lat = viewModel.latitude, let lon = viewModel.longitude, lat != 0, lon != 0 {
            getNearestLocation(from: CLLocationCoordinate2D(latitude: lat, longitude: lon)) { attractionName in
                nearestAttraction = attractionName
            }
        } else {
            nearestAttraction = nil
        }
    }

    private func getNearestLocation(from location: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        geocoder.reverseGeocodeLocation(clLocation) { placemarks, _ in
            if let placemark = placemarks?.first {
                var components: [String] = []
                if let poi = placemark.name, !poi.isEmpty, !poi.contains(where: { $0.isNumber }) {
                    components.append(poi)
                }
                if let neighborhood = placemark.subLocality, !neighborhood.isEmpty {
                    components.append(neighborhood)
                }
                if let city = placemark.locality, !city.isEmpty {
                    components.append(city)
                }
                if components.count >= 1, components.contains(where: { $0 == placemark.locality }) {
                    completion(components.joined(separator: ", "))
                    return
                }
            }

            let request = MKLocalSearch.Request()
            request.pointOfInterestFilter = .includingAll
            request.region = MKCoordinateRegion(center: location, latitudinalMeters: 1000, longitudinalMeters: 1000)

            MKLocalSearch(request: request).start { response, error in
                if error != nil {
                    completion(placemarks?.first?.locality)
                    return
                }
                guard let mapItems = response?.mapItems, !mapItems.isEmpty else {
                    completion(nil)
                    return
                }

                let sorted = mapItems.sorted {
                    CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
                        .distance(from: clLocation)
                    < CLLocation(latitude: $1.placemark.coordinate.latitude, longitude: $1.placemark.coordinate.longitude)
                        .distance(from: clLocation)
                }

                for item in sorted {
                    if let name = item.name, !name.isEmpty, !name.contains(where: { $0.isNumber }) {
                        let city = item.placemark.locality ?? ""
                        completion(city.isEmpty ? name : "\(name), \(city)")
                        return
                    }
                }

                var components: [String] = []
                if let n = sorted.first?.placemark.subLocality { components.append(n) }
                if let c = sorted.first?.placemark.locality { components.append(c) }
                let result = components.joined(separator: ", ")
                completion(result.isEmpty ? nil : result)
            }
        }
    }
}
