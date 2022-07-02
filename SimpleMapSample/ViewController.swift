//
//  ViewController.swift
//  SimpleMapSample
//
//  Created by Alexander von Below on 01.07.22.
//

import UIKit
import MapKit
import os.log

struct POIInfo {
    var name: String
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
}

class ViewController: UIViewController {

    @IBOutlet var mapView: MKMapView!
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!,
                        category: "Map")
    override func viewDidLoad() {
        super.viewDidLoad()

        let colognePOIs: [POIInfo] = [POIInfo(name: NSLocalizedString("Colonius",
                                                                      comment: "POI Cologne Radio Tower"),
                                              latitude: 50.947128,
                                              longitude: 6.931883),
        POIInfo(name: NSLocalizedString("Cologne Cathedral",
                                        comment: "POI Cologne Cathedral"),
                latitude: 50.94129,
                longitude: 6.95817),
        POIInfo(name: NSLocalizedString("Chocolate Museum",
                                        comment: "POI Cologne Chocolate Museum"),
                latitude: 50.932203,
                longitude: 6.964272),
        POIInfo(name: NSLocalizedString("Cologne Zoo",
                                        comment: "POI Cologne Zoo"),
                latitude: 50.958333,
                longitude: 6.973333)]
        
        registerMapAnnotationViews()
        
        for info in colognePOIs {
            let coordinate = CLLocationCoordinate2D(latitude: info.latitude,
                                                    longitude: info.longitude)
            let annotation = MKPointAnnotation()
            annotation.title = info.name
            annotation.coordinate = coordinate
            
            let overlay = MKCircle(center: coordinate,
                                   radius: 10)
            overlay.isAccessibilityElement = false
            mapView.addOverlay(overlay)
            mapView.addAnnotation(annotation)
            mapView.showAnnotations(mapView.annotations,
                                    animated: true)
        }

        setupCustomRotor()
    }
    
    let defaultReuseIdentifier = "defaultAnnotationView"
    private func registerMapAnnotationViews() {
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: defaultReuseIdentifier)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else {
            // Make a fast exit if the annotation is the `MKUserLocation`, as it's not an annotation view we wish to customize.
            return nil
        }
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: defaultReuseIdentifier,
                                                                   for: annotation)
        annotationView.canShowCallout = true
        annotationView.accessibilityTraits = [.button]
        let rightButton = UIButton(type: .infoLight)
        annotationView.rightCalloutAccessoryView = rightButton

        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKCircleRenderer(overlay: overlay)
        renderer.fillColor = UIColor.clear
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 2
        renderer.isAccessibilityElement = false
        return renderer
    }

    // What I am trying to do here is make the callout accessible
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let calloutView = view.rightCalloutAccessoryView
        calloutView?.isAccessibilityElement = true
        view.isAccessibilityElement = false
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        let calloutView = view.rightCalloutAccessoryView
        calloutView?.isAccessibilityElement = false
        view.isAccessibilityElement = true
    }
}

extension ViewController {
    func setupCustomRotor () {
        // https://stackoverflow.com/questions/42170870/create-a-custom-voiceover-rotor-to-navigate-mkannotationviews
        
        let markerRotor = UIAccessibilityCustomRotor(name: NSLocalizedString("Markers",
                                                                             comment: "Rotor Title"))
        { predicate in
            let forward = (predicate.searchDirection == .next)
            
            // which element is currently highlighted
            if (predicate.currentItem.targetElement == nil) {
                self.logger.info("Current Item Target Element is nil")
            }
            let currentAnnotationView = predicate.currentItem.targetElement as? MKAnnotationView
            if (currentAnnotationView == nil) {
                self.logger.error("Target Element is \(predicate.currentItem.targetElement.debugDescription)")
            }
            let currentAnnotation = (currentAnnotationView?.annotation as? MKAnnotation)
            
            // easy reference to all possible annotations
            let allAnnotations = self.mapView.annotations
            
            // we'll start our index either 1 less or 1 more, so we enter at either 0 or last element
            var currentIndex = forward ? -1 : allAnnotations.count
            
            // set our index to currentAnnotation's index if we can find it in allAnnotations
            if let currentAnnotation = currentAnnotation {
                if let index = allAnnotations.firstIndex(where: { (annotation) -> Bool in
                    return (annotation.coordinate.latitude == currentAnnotation.coordinate.latitude) &&
                    (annotation.coordinate.longitude == currentAnnotation.coordinate.longitude)
                }) {
                    currentIndex = index
                }
            }
            
            // now that we have our currentIndex, here's a helper to give us the next element
            // the user is requesting
            let nextIndex = {(index:Int) -> Int in forward ? index + 1 : index - 1}
            
            currentIndex = nextIndex(currentIndex)
            
            while currentIndex >= 0 && currentIndex < allAnnotations.count {
                let requestedAnnotation = allAnnotations[currentIndex]
                
                // i can't stress how important it is to have animated set to false. save yourself the 10 hours i burnt, and just go with it. if you set it to true, the map starts moving to the annotation, but there's no guarantee the annotation has an associated view yet, because it could still be animating. in which case the line below this one will be nil, and you'll have a whole bunch of annotations that can't be navigated to
                self.mapView.setCenter(requestedAnnotation.coordinate, animated: false)
                if let annotationView = self.mapView.view(for: requestedAnnotation) {
                    let title: String = (requestedAnnotation.title ?? "Unknown") ?? "Unknown"
                    self.logger.info("We want to be returning \(title) Index \(currentIndex)")
                    return UIAccessibilityCustomRotorItemResult(targetElement: annotationView, targetRange: nil)
                }
                
                currentIndex = nextIndex(currentIndex)
            }
            self.logger.info("We have nothing")
            return nil
        }
        self.mapView.accessibilityCustomRotors = [markerRotor]
    }
}
