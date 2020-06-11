//
//  MapViewController.swift
//  Colonnine
//
//  Created by Antonio Ferraioli on 17/02/2020.
//  Copyright © 2020 Antonio Ferraioli. All rights reserved.
//

import CoreLocation
import Foundation
import MapKit
import UIKit

public enum CardState {
    case collapsed
    case expanded
    case dismissed
}

public var titoloColonnina = ""
public var sottoTitoloColonnina = ""
public var dettagliTitoloColonnina = ""
public var minutiColonnina = ""
public var dettagliAlViaColonnina = ""
public var telefonoColonnina = ""
public var viaColonnina = ""
public var capColonnina = ""
public var statoColonnina = ""
public var distanza = ""
public var minuti = ""
public var numeroColonnine = Int()

let poiManager = PoiManager.getPoiManager()

class MapViewController: UIViewController, MKMapViewDelegate, UIViewControllerTransitioningDelegate, PoiManagerDelegate, searchControllerDelegate, FiltersDelegate, cardController{
    
    
    //    let locationManager = CLLocationManager()
    var centromappa = CLLocationCoordinate2D()
    var contoUpdateIniziale = 0
    
    @IBOutlet public var mappaView: MKMapView!
    @IBOutlet weak var ripositionButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var filtersButton: UIButton!
    
    // Current visible state of the card
    public var detailCardVisible = false
    public var searchCardVisible = false
    // Variable for card view controller
    var cardViewController:CardViewController!
    var searchViewController:SearchViewController!
    var filtersViewController:FiltersViewController!
//    var filterViewController:FiltersViewController!
    // Starting and end card heights will be determined later
    var endCardHeight:CGFloat = 0
    var startCardHeight:CGFloat = 0
    var searchCardHeight:CGFloat = 0
    // Empty property animator array
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted:CGFloat = 0
    var detailState = ""
    public var searchState = ""
    var constraintState = NSLayoutConstraint()
    
    @IBAction func ripositionAction(_ sender: Any) {
        let location = CLLocationCoordinate2D(latitude: mappaView.userLocation.coordinate.latitude, longitude: mappaView.userLocation.coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        let region = MKCoordinateRegion(center: location, span: span)
        mappaView.setRegion(region, animated: true)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        if(searchState == "collapsed"){
            searchCardVisible = false
            animateSearchTransitionIfNeeded(state: nextSearchState, duration: 0.5)
        }
        else if(searchState == "dismissed"){
            animateOnSearchButton(duration: 0.9)
        }
    }
    
    @IBAction func filterAction(_ sender: Any) {
        let filters = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "filters") as? FiltersViewController
        filtersViewController = filters!
        filtersViewController.delegate = self
        self.present(filters!, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.locationManager.requestWhenInUseAuthorization()
        mappaView.delegate = self
        mappaView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: (self.view.frame.height * 0.09), right: 0)
        poiManager.delegate = self
        
        mappaView.removeAnnotations(mappaView.annotations)
        mappaView.removeOverlays(mappaView.overlays)
        //    Bottone navigazione
        ripositionButton.layer.shadowColor = UIColor.black.cgColor
        ripositionButton.layer.shadowOffset = CGSize(width : 0.8 , height: 0.8)
        ripositionButton.layer.shadowRadius = 4.8
        ripositionButton.layer.shadowOpacity = 0.4
        //      Bottone cerca
        searchButton.layer.shadowColor = UIColor.black.cgColor
        searchButton.layer.shadowOffset = CGSize(width : 0.8 , height: 0.8)
        searchButton.layer.shadowRadius = 4.8
        searchButton.layer.shadowOpacity = 0.4
        //        Bottone filtri
        filtersButton.layer.shadowColor = UIColor.black.cgColor
        filtersButton.layer.shadowOffset = CGSize(width : 0.8 , height: 0.8)
        filtersButton.layer.shadowRadius = 4.8
        filtersButton.layer.shadowOpacity = 0.4
    }
    
    override func viewDidAppear(_ animated: Bool) {
        readCordinateOnStart()
        let location = CLLocationCoordinate2D(latitude: mappaView.userLocation.coordinate.latitude, longitude: mappaView.userLocation.coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        let region = MKCoordinateRegion(center: location, span: span)
        mappaView.setRegion(region, animated: true)
        centromappa = mappaView.centerCoordinate
        poiManager.getNearestPoi(latitude: mappaView.userLocation.coordinate.latitude, longitude: mappaView.userLocation.coordinate.longitude)
        setupSearchCard()
        setupDetailCard()
        searchViewController.delegate = self
        cardViewController.delegate = self
        super.viewDidAppear(animated)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if view.annotation is MKClusterAnnotation {
            let location = CLLocationCoordinate2D(latitude: (view.annotation?.coordinate.latitude)!, longitude: (view.annotation?.coordinate.longitude)!)
            let span = MKCoordinateSpan(latitudeDelta: mappaView.region.span.latitudeDelta - (mappaView.region.span.latitudeDelta * 0.85), longitudeDelta: mappaView.region.span.longitudeDelta - (mappaView.region.span.longitudeDelta * 0.85))
            let region = MKCoordinateRegion(center: location, span: span)
            mappaView.setRegion(region, animated: true)
        }
        else if ((view.annotation!.coordinate.latitude != mapView.userLocation.coordinate.latitude) && view.annotation!.coordinate.longitude != mapView.userLocation.coordinate.longitude) {
            mappaView.removeOverlays(mappaView.overlays)
            let directionRequest = MKDirections.Request()
            directionRequest.source = MKMapItem.forCurrentLocation()
            directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: view.annotation!.coordinate))
            directionRequest.transportType = .automobile
            let directions = MKDirections(request: directionRequest)
            
            directions.calculate{
                (response, error) -> Void in
                guard let response = response else {
                    if let error = error {
                        print("Error: \(error)")
                        DispatchQueue.main.async {
                            minuti = ""
                            distanza = ""
                            var trovato = false
                            var i = 0
                            while (i < (poiManager.poiData!.count - 1) && !trovato) {
                                if((view.annotation?.coordinate.latitude == poiManager.poiData![i].AddressInfo?.Latitude) && (view.annotation?.coordinate.longitude == poiManager.poiData![i].AddressInfo?.Longitude)){
                                    trovato = true
                                }
                                if (trovato){
                                    self.calcolaDettagli(poi: poiManager.poiData![i])
                                }
                                i = i + 1
                            }
                            self.cardViewController.latitude = (view.annotation?.coordinate.latitude)!
                            self.cardViewController.longitude = (view.annotation?.coordinate.longitude)!
                            self.cardViewController.Titolo.text = titoloColonnina
                            self.cardViewController.Sottotitolo.text = sottoTitoloColonnina
                            self.cardViewController.dettagliTitolo.text = dettagliTitoloColonnina
                            self.cardViewController.minuti.text = minutiColonnina
                            self.cardViewController.dettagliAlVai.text = dettagliAlViaColonnina
                            self.cardViewController.via.text = viaColonnina
                            self.cardViewController.cap.text = capColonnina
                            self.cardViewController.stato.text = statoColonnina
                            self.detailCardVisible = false
                            self.animateTransitionIfNeeded(state: self.nextDetailState2, duration: 0.9)
                        }
                    }
                    return
                }
                if !response.routes.isEmpty {
                    let route = response.routes[0]
                    DispatchQueue.main.async {
                        self.mappaView.addOverlay(route.polyline)
                        let minutes = Int(route.expectedTravelTime / 60)
                        
                        if minutes >= 60{
                            let hours = Int(minutes / 60)
                            let mins = minutes % 60
                            minuti = NSLocalizedString("\(hours)h \(mins)min", comment: "Minuti")
                        } else {
                            minuti = NSLocalizedString("\(minutes)min", comment: "Minuti")
                        }
                        distanza = "\(Int(route.distance / 1000)) km"
                        var trovato = false
                        var i = 0
                        while (i < (poiManager.poiData!.count - 1) && !trovato) {
                            if((view.annotation?.coordinate.latitude == poiManager.poiData![i].AddressInfo?.Latitude) && (view.annotation?.coordinate.longitude == poiManager.poiData![i].AddressInfo?.Longitude)){
                                trovato = true
                            }
                            if (trovato){
                                self.calcolaDettagli(poi: poiManager.poiData![i])
                            }
                            i = i + 1
                        }
                        self.cardViewController.latitude = (view.annotation?.coordinate.latitude)!
                        self.cardViewController.longitude = (view.annotation?.coordinate.longitude)!
                        self.cardViewController.Titolo.text = titoloColonnina
                        self.cardViewController.Sottotitolo.text = sottoTitoloColonnina
                        self.cardViewController.dettagliTitolo.text = dettagliTitoloColonnina
                        self.cardViewController.minuti.text = minutiColonnina
                        self.cardViewController.dettagliAlVai.text = dettagliAlViaColonnina
                        self.cardViewController.via.text = viaColonnina
                        self.cardViewController.cap.text = capColonnina
                        self.cardViewController.stato.text = statoColonnina
                        self.detailCardVisible = false
                        self.animateTransitionIfNeeded(state: self.nextDetailState2, duration: 0.9)
                    }
                }
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "customannotation")
        if (annotation.subtitle == NSLocalizedString("Operational • Public", comment: "Aperto-pubblico")){
            annotationView.image = UIImage(named: "pinAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Operational • Private", comment: "Aperto-privato")){
            annotationView.image = UIImage(named: "pinPrivateAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Closed • Public", comment: "Chiuso-pubblico")){
            annotationView.image = UIImage(named: "pinNotAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Closed • Private", comment: "Chiuso-privato")){
            annotationView.image = UIImage(named: "pinNotAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Operational • Private Residence", comment: "Abitazione-aperto")){
            annotationView.image = UIImage(named: "pinPrivateAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Closed • Private Residence", comment: "Abitazione-chiuso")){
            annotationView.image = UIImage(named: "pinNotAvaiable")
        }
        else if (annotation.subtitle == NSLocalizedString("Operational", comment: "Aperto")){
            annotationView.image = UIImage(named: "pinAvaiable")
        }
        else{
            if annotation is MKClusterAnnotation{
                annotationView.image = UIImage(named: "pinAvaiable")
            }
            else{
                annotationView.image = UIImage(named: "pinNotAvaiable")
            }
        }
        annotationView.frame = CGRect(x: 0, y: 0, width: 31.624, height: 42.184)
        annotationView.canShowCallout = true
        annotationView.clusteringIdentifier = "cluster"
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let mediacentromappa = (centromappa.latitude + centromappa.longitude)/2
        let medianuovacentromappa = (mappaView.centerCoordinate.latitude + mappaView.centerCoordinate.longitude)/2
        let mediauserlocation = (mappaView.userLocation.coordinate.latitude + mappaView.userLocation.coordinate.longitude)/2
        if (((mediauserlocation - medianuovacentromappa) < 0.001) && ((mediauserlocation - medianuovacentromappa) > -0.001)){
            ripositionButton.setImage(UIImage(named: "RipositionSelected"), for: UIControl.State.normal)
        }
        else{
            ripositionButton.setImage(UIImage(named: "RipositionUnselected"), for: UIControl.State.normal)
        }
        //print(medianuovacentromappa - mediacentromappa)
        if (((mediacentromappa - medianuovacentromappa) > 0.07) || ((mediacentromappa - medianuovacentromappa) < -0.07)){
            centromappa = mappaView.centerCoordinate
            poiManager.getFilteredPois(latitude: mappaView.centerCoordinate.latitude, longitude: mappaView.centerCoordinate.longitude)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKPolyline.self) {
            // draw the track
            let polyLine = overlay
            let polyLineRenderer = MKPolylineRenderer(overlay: polyLine)
            polyLineRenderer.strokeColor = .link
            polyLineRenderer.alpha = 0.8
            polyLineRenderer.lineWidth = 8.5
            polyLineRenderer.lineJoin = .round
            polyLineRenderer.lineCap = .round
            return polyLineRenderer
        }
        return MKPolylineRenderer()
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if contoUpdateIniziale <= 1 {
            let location = CLLocationCoordinate2D(latitude: mappaView.userLocation.coordinate.latitude, longitude: mappaView.userLocation.coordinate.longitude)
            let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            let region = MKCoordinateRegion(center: location, span: span)
            mappaView.setRegion(region, animated: true)
            poiManager.getNearestPoi(latitude: mappaView.userLocation.coordinate.latitude, longitude: mappaView.userLocation.coordinate.longitude)
            contoUpdateIniziale += 1
        }
    }
}

extension MapViewController{
    
    func calcolaDettagli(poi: PoiManager.PoiData) {
        if (poi.OperatorInfo?.Title == nil){
            titoloColonnina = NSLocalizedString("Unknown Company", comment: "Compagnia sconosciuta")
        }
        else if(poi.OperatorInfo?.Title == "Unknown Operator" || poi.OperatorInfo?.Title == "(Unknown Operator)"){
            titoloColonnina = NSLocalizedString("Unknown Company", comment: "Compagnia sconosciuta")
        }
        else{
            titoloColonnina = (poi.OperatorInfo?.Title!)!
        }
        let privato = poi.UsageType?.ID
        sottoTitoloColonnina = ""
        if (privato == 6 || privato == 2){
            sottoTitoloColonnina = NSLocalizedString("Private • ", comment: "Privato • ")
        }
        else if (privato == 4 || privato == 1 || privato == 5){
            sottoTitoloColonnina = NSLocalizedString("Public • ", comment: "Pubblico • ")
        }
        else if (privato == 3){
            sottoTitoloColonnina = NSLocalizedString("Private Residence • ", comment: "Abitazione Privata • ")
        }
        let operational = poi.StatusType?.IsOperational
        if (operational == true){
            sottoTitoloColonnina = sottoTitoloColonnina + NSLocalizedString("Operational", comment: "Aperto")
        }
        else{
            sottoTitoloColonnina = sottoTitoloColonnina + NSLocalizedString("Closed", comment: "Chiuso")
        }
        let costo = poi.UsageCost ?? nil
        if(costo != nil){
            sottoTitoloColonnina = sottoTitoloColonnina + " • \(costo!)"
        }
        let via = poi.AddressInfo?.AddressLine1 ?? ""
        if(distanza != ""){
            dettagliTitoloColonnina = "\(distanza) • " + via
        }
        else if(distanza == ""){
            dettagliTitoloColonnina = via
        }
        let nomeLocale = poi.AddressInfo?.Title ?? ""
        if(nomeLocale == ""){
            minutiColonnina = "\(minuti)"
        }
        else if (nomeLocale != "" && minuti != ""){
            minutiColonnina = "\(minuti) • " + "\(nomeLocale)"
        }
        else if (nomeLocale != "" && minuti == ""){
            minutiColonnina = "\(nomeLocale)"
        }
        let citta = poi.AddressInfo?.Town ?? nil
        if(distanza != ""){
            distanza = "\(distanza) • "
        }
        if (citta != nil && via != ""){
            dettagliAlViaColonnina  = "\(distanza)" + "\(via) • " + citta!
        }
        else if(citta != nil && via == ""){
            dettagliAlViaColonnina  = "\(distanza)" + citta!
        }
        else if(citta == nil && via != ""){
            dettagliAlViaColonnina  = "\(distanza)" + "\(via)"
        }
        else if(citta == nil && via == ""){
            dettagliAlViaColonnina  = "\(distanza)"
        }
        telefonoColonnina = poi.AddressInfo?.ContactTelephone1 ?? ""
        viaColonnina = via
        capColonnina = poi.AddressInfo?.Postcode ?? NSLocalizedString("Unknown Postal Code/CAP", comment: "Cap sconosciuto")
        statoColonnina = poi.AddressInfo?.Country?.ISOCode ?? ""
//        DispatchQueue.main.async {
//            arrImages = poiManager.getImages(for: poi) ?? []
//            print("aaaa\(arrImages)")
//        }
//        self.cardViewController.faiscroll()
        numeroColonnine = Int()
        numeroColonnine = poi.Connections!.count
        let plugbutton = [self.cardViewController.plugButton1, self.cardViewController.plugButton2, self.cardViewController.plugButton3, self.cardViewController.plugButton4, self.cardViewController.plugButton5, self.cardViewController.plugButton6, self.cardViewController.plugButton7, self.cardViewController.plugButton8]
        let plugimage = [self.cardViewController.plugImage1, self.cardViewController.plugImage2, self.cardViewController.plugImage3, self.cardViewController.plugImage4, self.cardViewController.plugImage5, self.cardViewController.plugImage6, self.cardViewController.plugImage7, self.cardViewController.plugImage8]
        let plugtype = [self.cardViewController.plugType1, self.cardViewController.plugType2, self.cardViewController.plugType3, self.cardViewController.plugType4, self.cardViewController.plugType5, self.cardViewController.plugType6, self.cardViewController.plugType7, self.cardViewController.plugType8]
        let plugtypedescription = [self.cardViewController.plugTypeDescription1, self.cardViewController.plugTypeDescription2, self.cardViewController.plugTypeDescription3, self.cardViewController.plugTypeDescription4, self.cardViewController.plugTypeDescription5, self.cardViewController.plugTypeDescription6, self.cardViewController.plugTypeDescription7, self.cardViewController.plugTypeDescription8]
        let plugnumber = [self.cardViewController.plugNumber1, self.cardViewController.plugNumber2, self.cardViewController.plugNumber3, self.cardViewController.plugNumber4, self.cardViewController.plugNumber5, self.cardViewController.plugNumber6, self.cardViewController.plugNumber7, self.cardViewController.plugNumber8]
        var titolotemporaneo = ""
        var descrizionetemporanea = ""
        var idtemporaneo = Int()
        var c = 0
        while(c <= 7){
            if(c <= numeroColonnine - 1){
                plugbutton[c]!.isHidden = false
                plugimage[c]!.isHidden = false
                plugtypedescription[c]!.isHidden = false
                plugtype[c]!.isHidden = false
                plugnumber[c]!.isHidden = false
                if(poi.Connections![c].PowerKW != nil){
                    descrizionetemporanea = "\(Int(poi.Connections![c].PowerKW!))kW"
                }
                if(poi.Connections![c].Voltage != nil && poi.Connections![c].PowerKW != nil){
                    descrizionetemporanea = "\(descrizionetemporanea) • \(Int(poi.Connections![c].Voltage!))V"
                }
                else if(poi.Connections![c].Voltage != nil){
                    descrizionetemporanea = "\(Int(poi.Connections![c].Voltage!))V"
                }
                idtemporaneo = poi.Connections![c].ConnectionTypeID ?? 0
                if(idtemporaneo == 25 || idtemporaneo == 1036){
                    plugimage[c]?.image = UIImage(named: "Type2MANNSelected")
                }
                else if(idtemporaneo == 33 || idtemporaneo == 32){
                    plugimage[c]?.image = UIImage(named: /*"CCSSelected"*/"CCSSelected")
                }
                else if(idtemporaneo == 8 || idtemporaneo == 27 || idtemporaneo == 30 || idtemporaneo == 31){
                    plugimage[c]?.image = UIImage(named: "TESLASelected")
                }
                else if(idtemporaneo == 2){
                    plugimage[c]?.image = UIImage(named: "CHAdeMOSelected")
                }
                else if(idtemporaneo == 13 || idtemporaneo == 16 || idtemporaneo == 17 || idtemporaneo == 18 || idtemporaneo == 23 || idtemporaneo == 28){
                    plugimage[c]?.image = UIImage(named: /*"CEESelected"*/ "CEESelected")
                }
                else if(idtemporaneo == 1){
                    plugimage[c]?.image = UIImage(named:
                        /*"Type1Selected"*/ "Type1Selected")
                }
                else if(idtemporaneo == 9 || idtemporaneo == 10 || idtemporaneo == 11 || idtemporaneo == 14 || idtemporaneo == 15 || idtemporaneo == 22 || idtemporaneo == 1042){
                    plugimage[c]?.image = UIImage(named: /*"NemaSelected"*/"NEMASelected")
                }
                else if(idtemporaneo == 35 || idtemporaneo == 1041){
                    plugimage[c]?.image = UIImage(named: "ThreePhaseSelected")
                }
                else if(idtemporaneo == 0){
                    plugimage[c]?.image = UIImage(named: "OtherPlugSelected")
                }
                else {
                    plugimage[c]?.image = UIImage(named: "OtherPlugSelected")
                }
                if(poi.Connections![c].ConnectionType?.Title == "Unknown"){
                    titolotemporaneo = NSLocalizedString("Unknown Plug", comment: "Plug Sconosciuto")
                }
                else{
                    titolotemporaneo = poi.Connections![c].ConnectionType?.Title ?? "Not specified"
                }
                plugtype[c]?.text = "\(titolotemporaneo)"
                plugtypedescription[c]!.text = "\(descrizionetemporanea)"
                plugnumber[c]?.text = "x\(poi.Connections![c].Quantity ?? 1)"
                if(c == numeroColonnine - 1){
                    self.cardViewController.view.removeConstraint(constraintState)
                    constraintState = NSLayoutConstraint(item: self.cardViewController.linea3!, attribute: .top, relatedBy: .equal, toItem: plugbutton[c], attribute: .bottom, multiplier: 1, constant: 14)
                    self.cardViewController.view.addConstraint(constraintState)
                }
            }
            else{
                plugbutton[c]!.isHidden = true
                plugimage[c]!.isHidden = true
                plugtypedescription[c]!.isHidden = true
                plugtype[c]!.isHidden = true
                plugnumber[c]!.isHidden = true
            }
            c += 1
        }
        self.cardViewController.providerName.text = poi.DataProvider?.Title ?? "Open Charge Map Contributors"
        self.cardViewController.providerSito.text = poi.DataProvider?.WebsiteURL ?? "http://openchargemap.org"
        self.cardViewController.providerLicense.text = poi.DataProvider?.License ?? "License not avaiable"
    }
    
    private func fillCardWithDetails(of poi: PoiManager.PoiData, withRoute route: MKRoute?)
    {
        if (route != nil){
            self.mappaView.addOverlay(route!.polyline)
            let minutes = Int(route!.expectedTravelTime / 60)
            
            if minutes >= 60{
                let hours = Int(minutes / 60)
                let mins = minutes % 60
                minuti = NSLocalizedString("\(hours)h \(mins)min", comment: "Minuti")
            } else {
                minuti = NSLocalizedString("\(minutes)min", comment: "Minuti")
            }
            distanza = "\(Int(route!.distance / 1000)) km"
            self.calcolaDettagli(poi: poi)
            sottoTitoloColonnina = "\(titoloColonnina) • " + sottoTitoloColonnina
            titoloColonnina = NSLocalizedString("Nearest to you", comment: "Compagnia sconosciuta")
            self.cardViewController.latitude = (poi.AddressInfo?.Latitude)!
            self.cardViewController.longitude = (poi.AddressInfo?.Longitude)!
            self.cardViewController.Titolo.text = titoloColonnina
            self.cardViewController.Sottotitolo.text = sottoTitoloColonnina
            self.cardViewController.dettagliTitolo.text = dettagliTitoloColonnina
            self.cardViewController.minuti.text = minutiColonnina
            self.cardViewController.dettagliAlVai.text = dettagliAlViaColonnina
            self.cardViewController.via.text = viaColonnina
            self.cardViewController.cap.text = capColonnina
            self.cardViewController.stato.text = statoColonnina
            self.detailCardVisible = false
            self.animateTransitionIfNeeded(state: self.nextDetailState2, duration: 0.9)
        }
    }
    
    func calculateRoute(to poi: PoiManager.PoiData){
        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem.forCurrentLocation()
        
        directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2DMake((poi.AddressInfo?.Latitude!)!, (poi.AddressInfo?.Longitude!)!)))
        directionRequest.transportType = .automobile
        let directions = MKDirections(request: directionRequest)
        
        directions.calculate{
            (response, error) -> Void in
            guard let response = response else {
                if let error = error {
                    print("Error: \(error)")
                    DispatchQueue.main.async {
                        minuti = ""
                        distanza = ""
                        self.calcolaDettagli(poi: poi)
                        self.cardViewController.latitude = (poi.AddressInfo?.Latitude)!
                        self.cardViewController.longitude = (poi.AddressInfo?.Longitude)!
                        self.cardViewController.Titolo.text = titoloColonnina
                        self.cardViewController.Sottotitolo.text = sottoTitoloColonnina
                        self.cardViewController.dettagliTitolo.text = dettagliTitoloColonnina
                        self.cardViewController.minuti.text = minutiColonnina
                        self.cardViewController.dettagliAlVai.text = dettagliAlViaColonnina
                        self.cardViewController.via.text = viaColonnina
                        self.cardViewController.cap.text = capColonnina
                        self.cardViewController.stato.text = statoColonnina
                        self.detailCardVisible = false
                        self.animateTransitionIfNeeded(state: self.nextDetailState2, duration: 0.9)
                    }
                }
                DispatchQueue.main.async {
                    self.popDetailView(with: poi)
                }
                return
            }
            if !response.routes.isEmpty {
                let route = response.routes[0]
                DispatchQueue.main.async {
                    self.mappaView.addOverlay(route.polyline)
                    self.fillCardWithDetails(of: poi, withRoute: route)
                    //                    self.detailCardVisible = false
                    //                    self.animateTransitionIfNeeded(state: self.nextDetailState2, duration: 0.9)
                }
            }
        }
    }
    
    private func popDetailView(with poi: PoiManager.PoiData){
        self.fillCardWithDetails(of: poi, withRoute: nil)
        detailCardVisible = false
        self.animateTransitionIfNeeded(state: nextDetailState2, duration: 0.9)
    }
    
    public func addAnnotation(for poi: PoiManager.PoiData){
        
        let annotazione = MKPointAnnotation()
        if (poi.OperatorInfo?.Title == nil){
            annotazione.title = NSLocalizedString("Unknown Company", comment: "Compagnia sconosciuta")
        }
        else if (poi.OperatorInfo?.Title == "Unknown Operator"){
            annotazione.title = NSLocalizedString("Unknown Company", comment: "Compagnia sconosciuta")
        }
        else if (poi.OperatorInfo?.Title == "(Unknown Operator)"){
            annotazione.title = NSLocalizedString("Unknown Company", comment: "Compagnia sconosciuta")
        }
        else{
            annotazione.title = poi.OperatorInfo?.Title
        }
        let operational = poi.StatusType?.IsOperational
        if (operational == true && poi.UsageType?.ID == 4 || operational == true && poi.UsageType?.ID == 1 || operational == true && poi.UsageType?.ID == 5){
            annotazione.subtitle = NSLocalizedString("Operational • Public", comment: "Aperto-pubblico")
        }
        else if (operational == true && poi.UsageType?.ID == 6 || operational == true && poi.UsageType?.ID == 2){
            annotazione.subtitle = NSLocalizedString("Operational • Private", comment: "Aperto-privato")
        }
        else if (operational == false && poi.UsageType?.ID == 4 || operational == false && poi.UsageType?.ID == 1 || operational == false && poi.UsageType?.ID == 5){
            annotazione.subtitle = NSLocalizedString("Closed • Public", comment: "Chiuso-pubblico")
        }
        else if (operational == false && poi.UsageType?.ID == 6 || operational == false && poi.UsageType?.ID == 2){
            annotazione.subtitle = NSLocalizedString("Closed • Private", comment: "Chiuso-privato")
        }
        else if (operational == true && poi.UsageType?.ID == 3){
            annotazione.subtitle = NSLocalizedString("Operational • Private Residence", comment: "Abitazione-aperto")
        }
        else if (operational == false && poi.UsageType?.ID == 3){
            annotazione.subtitle = NSLocalizedString("Closed • Private Residence", comment: "Abitazione-chiuso")
        }
        else if (operational == true && poi.UsageType?.ID != 0 || operational == true && poi.UsageType?.ID != 1 || operational == true && poi.UsageType?.ID != 2 || operational == true && poi.UsageType?.ID != 3 || operational == true && poi.UsageType?.ID != 4 || operational == true && poi.UsageType?.ID != 5 || operational == true && poi.UsageType?.ID != 6){
            annotazione.subtitle = NSLocalizedString("Operational", comment: "Aperto")
        }
        else{
            annotazione.subtitle = NSLocalizedString("Closed", comment: "Chiuso")
        }
        annotazione.coordinate = CLLocationCoordinate2D(latitude: poi.AddressInfo!.Latitude!, longitude: poi.AddressInfo!.Longitude!)
        DispatchQueue.main.async {
            self.mappaView.addAnnotation(annotazione)
        }
        //        print("added \(mappaView.annotations.count)")
    }
    
    func removeAnnotation(for poi: PoiManager.PoiData){
        let annotations = mappaView.annotations
        for annotation in annotations{
            if (annotation.coordinate.latitude == poi.AddressInfo?.Latitude && annotation.coordinate.longitude == poi.AddressInfo?.Longitude){
                DispatchQueue.main.async {
                    self.mappaView.removeAnnotation(annotation)
                }
                //                print("REMOVED \(mappaView.annotations.count)")
                return
            }
        }
    }
    
   public func removeAllAnnotations() {
        DispatchQueue.main.async {
            self.mappaView.removeOverlays(self.mappaView.overlays)
            self.mappaView.removeAnnotations(self.mappaView.annotations)
        }
    }
    
    func readCordinateOnStart() {
        var i = 0
        //        print(poiManager.poiData?.count)
        while (i < (poiManager.poiData!.count - 1)) {
            addAnnotation(for: poiManager.poiData![i])
            i += 1
        }
    }
    
    public func zoomOnRegion(cordinate: CLLocationCoordinate2D){
        let location = CLLocationCoordinate2D(latitude: cordinate.latitude, longitude: cordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        let region = MKCoordinateRegion(center: location, span: span)
        mappaView.setRegion(region, animated: true)
    }
}
