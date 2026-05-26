//
//  MapView.swift
//  ToDoList
//
//  Created by Adrian Leventiu on 18.10.2024.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {
    var mapType: MKMapType
    var animated: Bool
    var altitude: Double // This is the altitude for zoom level
    var currentPin: MKAnnotation? // Track the current pin
    var startLocation: CLLocationCoordinate2D?
    var showsUserLocation: Bool?
    var onPinSelected: (CLLocationCoordinate2D) -> Void // Closure to pass the selected coordinate back
    var onPinAdded: (CLLocationCoordinate2D) -> Void // Closure to handle new pin addition

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = mapType
        mapView.delegate = context.coordinator

        // Set the initial center and zoom level
        if let coord = startLocation {
            // Offset the center point slightly upward to account for the search bar overlay
            let offsetCoordinate = CLLocationCoordinate2D(
                latitude: coord.latitude + 0.002, // Slightly shift the center point south
                longitude: coord.longitude
            )
            let camera = MKMapCamera(lookingAtCenter: offsetCoordinate, fromDistance: altitude, pitch: 0, heading: 0)
            mapView.setCamera(camera, animated: animated)
        }

        // Add the existing pin if available
        if let pin = currentPin {
            mapView.addAnnotation(pin)
        }

        if let optionalUserLoc = showsUserLocation {
            mapView.showsUserLocation = optionalUserLoc
        }

        // Add a tap gesture recognizer to the map view
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Clear existing pins and add the new one if available
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) }) // Remove old pins but keep user location
        
        if let pin = currentPin {
            mapView.addAnnotation(pin) // Add the new/current pin
            
            // Center the map on the pin with animation, with the slight offset
            let offsetCoordinate = CLLocationCoordinate2D(
                latitude: pin.coordinate.latitude + 0.002, // Slightly shift the center point south
                longitude: pin.coordinate.longitude
            )
            let camera = MKMapCamera(lookingAtCenter: offsetCoordinate, fromDistance: altitude, pitch: 0, heading: 0)
            mapView.setCamera(camera, animated: animated)
        }
    }
    
    func makeCoordinator() -> MapView.Coordinator {
        return Coordinator(self)
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        var control: MapView
        
        init(_ control: MapView) {
            self.control = control
        }
        
        // Handle taps on the map to add or update the pin
        @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            let coordinate = (gestureRecognizer.view as! MKMapView).convert(location, toCoordinateFrom: gestureRecognizer.view)

            // Create a new pin
            let newPin = MKPointAnnotation()
            newPin.coordinate = coordinate
            newPin.title = "New Pin"

            // Update the current pin and notify the parent view
            control.onPinAdded(coordinate) // Notify to update the selected location
            
            // Remove old annotations and add the new pin
            let mapView = gestureRecognizer.view as! MKMapView
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            mapView.addAnnotation(newPin) // Add the new pin
            
            // Recenter with offset for better visibility with search results
            let offsetCoordinate = CLLocationCoordinate2D(
                latitude: coordinate.latitude + 0.002, // Slightly shift the center point south
                longitude: coordinate.longitude
            )
            let camera = MKMapCamera(lookingAtCenter: offsetCoordinate, fromDistance: control.altitude, pitch: 0, heading: 0)
            mapView.setCamera(camera, animated: control.animated)
        }
        
        // Handle selection of existing pins
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation {
                control.onPinSelected(annotation.coordinate)
            }
        }
        
        // Customize the pin appearance
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location pin
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "LocationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}
