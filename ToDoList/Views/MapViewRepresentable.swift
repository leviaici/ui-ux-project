//
//  MapViewRepresentable.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 20.05.2025.
//

import SwiftUI
import MapKit

// MapView that can display multiple routes
struct MapViewRepresentable: UIViewRepresentable {
    // Using non-binding route data for simplicity
    let routes: [MKRoute]
    let selectedRouteIndex: Int
    @Binding var region: MKCoordinateRegion
    let routeColors: [Color]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Remove existing annotations except user location
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotations)
        
        // Add route polylines directly
        for (index, route) in routes.enumerated() {
            let isSelected = index == selectedRouteIndex
            
            // Store route information in coordinator for rendering
            context.coordinator.routeStyles[route.polyline] = (index, isSelected)
            
            // Add the polyline to the map
            mapView.addOverlay(route.polyline)
        }
        
        // Add destination annotation if we have routes
        if let lastRoute = routes.first {
            let destinationAnnotation = MKPointAnnotation()
            destinationAnnotation.coordinate = lastRoute.polyline.points()[lastRoute.polyline.pointCount - 1].coordinate
            mapView.addAnnotation(destinationAnnotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var routeStyles: [MKPolyline: (Int, Bool)] = [:] // [polyline: (index, isSelected)]
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        // Style the route lines
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline, let (index, isSelected) = routeStyles[polyline] {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Convert SwiftUI Color to UIColor
                let color = parent.routeColors[index % parent.routeColors.count]
                let uiColor = UIColor(color)
                
                renderer.strokeColor = uiColor
                renderer.lineWidth = isSelected ? 5 : 3
                renderer.alpha = isSelected ? 1.0 : 0.7
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // Customize annotation appearance
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
                markerView.glyphImage = UIImage(systemName: "mappin")
            }
            
            return annotationView
        }
    }
}
