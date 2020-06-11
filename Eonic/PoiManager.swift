//
//  PoiManager.swift
//  Colonnine
//
//  Created by Simone Punzo on 17/02/2020.
//  Copyright © 2020 Antonio Ferraioli. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

protocol PoiManagerDelegate{
    func addAnnotation(for poi: PoiManager.PoiData)
    func removeAnnotation(for poi: PoiManager.PoiData)
    func calculateRoute(to poi: PoiManager.PoiData)
}

public class PoiManager: NSObject, URLSessionDelegate{
    
    static let singleton = PoiManager()
    
    
    static func getPoiManager() -> PoiManager {
        return .singleton
    }
    
    private override init() {
        super.init()
        //        poiCache.emptyCache()
        poiData = poiCache.getAllValues()
    }
    
    var delegate:PoiManagerDelegate!
    
    struct DataProviderStatusType: Codable {
        let IsProviderEnabled: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct DataProvider: Codable {
        let WebsiteURL: String?
        let Comments: String?
        let DataProviderStatusType: DataProviderStatusType
        let IsRestrictedEdit: Bool?
        let IsOpenDataLicensed: Bool?
        let IsApprovedImport: Bool?
        let License: String?
        let DateLastImported: String?
        let ID: Int?
        let Title: String?
    }
    
    struct OperatorInfo: Codable {
        let WebsiteURL: String?
        let Comments: String?
        
        // penso string ma è da controllare
        let PhonePrimaryContact: String?
        let PhoneSecondaryContact: String?
        // // // // // //
        
        let IsPrivateIndividual: Bool?
        let AddressInfo: String?
        let BookingURL: String?
        let ContactEmail: String?
        let FaultReportEmail: String?
        let IsRestrictedEdit: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct UsageType: Codable {
        let IsPayAtLocation: Bool?
        let IsMembershipRequired: Bool?
        let IsAccessKeyRequired: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct StatusType: Codable {
        let IsOperational: Bool?
        let IsUserSelectable: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct SubmissionStatus: Codable {
        let IsLive: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct Country: Codable {
        let ISOCode: String?
        let ContinentCode: String?
        let ID: Int?
        let Title: String?
    }
    
    struct AddressInfo: Codable {
        let ID: Int?
        let Title: String?
        let AddressLine1: String?
        let AddressLine2: String?
        let Town: String?
        let StateOrProvince: String?
        let Postcode: String?
        let CountryID: Int?
        let Country: Country?
        var Latitude: Double?
        let Longitude: Double?
        let ContactTelephone1: String?
        let ContactTelephone2: String?
        let ContactEmail: String?
        let CccessComments: Bool? // che cazzo è, ho messo il tipo a caso
        let RelatedUrl: String?
        let Distance: Double?
        let DistanceUnit: Int?
    }
    
    struct ConnectionType: Codable {
        let FormalName: String?
        let IsDiscontinued: Bool?
        let IsObsolete: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct ConnectionStatusType: Codable {
        let IsOperational: Bool?
        let IsUserSelectable: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct Level: Codable {
        let Comments: String?
        let IsFastChargeCapable: Bool?
        let ID: Int?
        let Title: String?
    }
    
    struct CurrentType: Codable {
        let Description: String?
        let ID: Int?
        let Title: String?
    }
    
    struct Connection: Codable {
        let ID: Int?
        let ConnectionTypeID: Int?
        let ConnectionType: ConnectionType?
        let Reference: String? // penso sia string
        let StatusTypeID: Int?
        let StatusType: ConnectionStatusType?
        let LevelID: Int?
        let Level: Level?
        let Amps: Int?
        let Voltage: Int?
        let PowerKW: Float?
        let CurrentTypeID: Int?
        let CurrentType: CurrentType?
        let Quantity: Int?
        let Comments: String?
    }
    struct MediaItem: Codable {
        let ItemURL: String?
        let ItemThumbnailURL:String?
        let IsVideo: Bool?
    }
    
    public struct PoiData: Codable {
        let DataProvider: DataProvider?
        let OperatorInfo: OperatorInfo?
        let UsageType: UsageType?
        let StatusType: StatusType?
        let SubmissionStatus: SubmissionStatus?
        // let UserComments: [String]?
        
        let PercentageSimilarity: Int? // o double???
        let MediaItems: [MediaItem]? //non ne ho idea se è string
        let IsRecentlyVerified: Bool?
        let DateLastVerified: String? // Date
        let ID: Int?
        let UUID: String?
        let ParentChargePointID: Int?
        let DataProviderID: Int?
        let DataProvidersReference: String? // bho, non so se è string
        let OperatorID: Int?
        let OperatorsReference: String? // anche qui non so se è string
        let UsageTypeID: Int?
        let UsageCost: String?
        let AddressInfo: AddressInfo?
        let Connections: [Connection]?
        let NumberOfPoints: Int?
        let GeneralComments: String?
        let DatePlanned: String? // penso sia date ce
        let DateLastConfirmed: String?
        let StatusTypeID: Int?
        let DateLastStatusUpdate: String?
        //let MetadataValues: [String]? // che cazzo sono sti metadata, penso string
        let DataQualityLevel: Int?
        let DateCreated: String?
        let SubmissionStatusTypeID: Int?
    }
    
    var poiCache: Cache<String, PoiManager.PoiData> = {
        let cache = Cache<String, PoiManager.PoiData>()
        return cache.loadCache(withName: "poiCache")
    }()
    
    var poiData: [PoiData]?
    let size = 2000
    let poiQueue = DispatchQueue(label: "poiQueue")
    
    private func insert(new poi: PoiManager.PoiData){
        if poiData?.count == size {
            let removePoi = poiData!.first!
            self.poiCache.removeValue(forKey: removePoi.UUID!)
            self.poiData?.remove(at: 0)
            self.poiData?.append(poi)
            self.poiCache.insert(poi, forKey: poi.UUID!)
            //                print("poi added \(self.poiData?.count)")
            self.delegate.removeAnnotation(for: removePoi)
            self.delegate.addAnnotation(for: poi)
        }else{
            self.poiData?.append(poi)
            self.poiCache.insert(poi, forKey: poi.UUID!)
            //                print("poi added \(self.poiData?.count)")
            self.delegate.addAnnotation(for: poi)
        }
    }
    
    public func getPois(latitude: Double, longitude: Double) {
        let url = URL(string: "https://api.openchargemap.io/v3/poi/?output=json&key=bb711b10-cc7d-4a83-919f-f8edeb10d2b8&latitude=\(latitude)&longitude=\(longitude)&maxresults=1000&distance=50&distanceunite=km")!
        
        let configuration = URLSession.shared.configuration
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            self.readJson(data: data)
            print("eseguito")
        }
        task.taskDescription = "getPois"
        task.resume()
    }
    
    
    
    public func getImages(for poi: PoiManager.PoiData) ->[UIImage]? {
        let configuration = URLSession.shared.configuration
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        
        var images: [UIImage] = []
        let group = DispatchGroup()
        group.enter()
        
        for image in poi.MediaItems ?? []{
            let url = URL(string: image.ItemThumbnailURL!)!
            
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            print("aa")
            let task = session.dataTask(with: url) { data, _, _ in
                guard let data = data else { return }
                print("bb")
                let myImage = UIImage(data: data)
                if myImage != nil{
                    images.append(myImage!)
                    print(images)
                    if (images.count == poi.MediaItems?.count){
                        group.leave()
                    }
                }
                else{
                    group.leave()
                }
            }
            task.taskDescription = "getImages"
            task.resume()
        }
        if (poi.MediaItems == nil){
            group.leave()
        }
        group.wait()
        return images
    }
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        //        print("siamo dentro urlSession")
        switch task.taskDescription{
            
        case "getNearestPoi":
            task.cancel()
            self.searchNearestPoi()
            
        default:
            return
        }
    }
    
    //    var nearestPoi: PoiData = {
    //        var nearestPoi = poiData?.first
    //        for poi in poiData ?? []{
    //            let location = CLLocation(latitude: (poi.AddressInfo?.Latitude) ?? 0, longitude: (poi.AddressInfo?.Longitude) ?? 0)
    //            let nearestPoiLocation = CLLocation(latitude: nearestPoi?.AddressInfo?.Latitude ?? 0, longitude: nearestPoi?.AddressInfo?.Longitude ?? 0)
    //            let distance1: Double = (locationManager.locationManager.location?.distance(from: nearestPoiLocation))! //as! Double
    //            let distance2: Double = (locationManager.locationManager.location?.distance(from: location))! //as! Double
    //            //            print("OOOOOOOOOOOOOOOOOOO \(distance1)")
    //            //            print(distance2)
    //            if( distance2 < distance1 ){
    //                nearestPoi = poi
    //            }
    //        }
    //        return nearestPoi
    //    }()
    
    func searchNearestPoi(){
        var nearestPoi = poiData?.first
        for poi in poiData ?? []{
            let location = CLLocation(latitude: (poi.AddressInfo?.Latitude) ?? 0, longitude: (poi.AddressInfo?.Longitude) ?? 0)
            let nearestPoiLocation = CLLocation(latitude: nearestPoi?.AddressInfo?.Latitude ?? 0, longitude: nearestPoi?.AddressInfo?.Longitude ?? 0)
            let distance1: Double = (locationManager.locationManager.location?.distance(from: nearestPoiLocation))! //as! Double
            let distance2: Double = (locationManager.locationManager.location?.distance(from: location))! //as! Double
            //            print("OOOOOOOOOOOOOOOOOOO \(distance1)")
            //            print(distance2)
            if( distance2 < distance1 ){
                nearestPoi = poi
            }
        }
        delegate.calculateRoute(to: nearestPoi!)
    }
    
    func getNearestPoi(latitude: Double, longitude: Double) {
        
        let filterString: String? = UserDefaults.standard.value(forKey: "Filters") as? String
        
        let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&latitude=\(latitude)&longitude=\(longitude)&maxresults=1" + (filterString ?? ""))!
        
        let configuration = URLSession.shared.configuration
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 5
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        var nearestPoi: [PoiData]?
        
        let task = session.dataTask(with: url) {data, _, error in
            
            if error != nil{
                self.searchNearestPoi()
                return
            }
            guard let data = data else { return }
            do {
                let decoder: JSONDecoder = JSONDecoder()
                nearestPoi = try decoder.decode([PoiData].self, from: data)
                if(nearestPoi?.first != nil){
                    self.poiQueue.sync {
                        if (!self.poiData!.contains(where: {$0.ID == nearestPoi!.first!.ID})){
                            self.insert(new: nearestPoi!.first!)
                        }
                        self.delegate.calculateRoute(to: nearestPoi!.first!)
                    }
                }
            }catch{
            }
        }
        task.taskDescription = "getNearestPoi"
        task.resume()
    }
    
    public func getFilteredPois(latitude: Double, longitude: Double){
        
        let filterString: String? = UserDefaults.standard.value(forKey: "Filters") as? String
        
        let url = URL(string: "https://api.openchargemap.io/v3/poi/?output=json&key=bb711b10-cc7d-4a83-919f-f8edeb10d2b8&latitude=\(latitude)&longitude=\(longitude)&maxresults=1000&distance=50&distanceunite=km" + (filterString ?? ""))!
//        print(url)
        
        let configuration = URLSession.shared.configuration
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            self.readJson(data: data)
            print("eseguito")
        }
        task.taskDescription = "getPois"
        task.resume()
    }
    
    
    /*
     
     func getNearestLevelPoi(latitude: Double, longitude: Double, levelId: Int) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&LevelID=\(levelId)&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     
     func getNearestConnectorPoi(latitude: Double, longitude: Double, connectionTypeId: Int) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&ConnectionTypeId=\(connectionTypeId)&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     
     func getNearestTeslaPoi(latitude: Double, longitude: Double) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&operatorid=23&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     
     Tesla operatorID 23 , Enel 80
     func getNearestOperatorPoi(latitude: Double, longitude: Double, operatorId: Int) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&operatorid=\(operatorId)&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     
     func getNearestEnelPoi(latitude: Double, longitude: Double) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&operatorid=80&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     
     func getPoiInADistanceRange(latitude: Double, longitude: Double, range: Float) {
     let url = URL(string: "https:api.openchargemap.io/v3/poi/?output=json&countrycode=IT&latitude=\(latitude)&longitude=\(longitude)&distance=\(range)&maxresults=30")!
     
     let task = URLSession.shared.dataTask(with: url) { data, _, _ in
     guard let data = data else { return }
     self.readJson(data: data)
     print(String(data: data, encoding: .utf8)!)
     }
     
     task.resume()
     }
     */
    
    func getPoiForAFilter(filters : [(filterName : String,  filterValues : [String])])
    {
        var stringa : String = ""
        var i : Int = 1
        for elem in filters
        {
            stringa += "&" + elem.filterName + "=" + elem.filterValues[0]
            i=1
            while(i<elem.filterValues.count)
            {
                stringa += "," + elem.filterValues[i]
                i+=1
            }
        }
        
        let url = URL(string: "https://api.openchargemap.io/v3/poi/?output=json"+stringa)!
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            self.readJson(data: data)
            print(String(data: data, encoding: .utf8)!)
        }
        task.resume()
    }
    
    func readJson(data: Data) {
        var poiData1 = [PoiData]()
        do {
            let decoder: JSONDecoder = JSONDecoder()
            poiData1 = try decoder.decode([PoiData].self, from: data)
            if poiData == nil{
                poiData = poiData1
                print("era vuoto")
                //                return
            }
            var i = 0
            while (i < (poiData1.count - 1)) {
                poiQueue.sync {
                    if (!poiData!.contains(where: {$0.ID == poiData1[i].ID})){
                        self.insert(new: poiData1[i])
                    }
                    //                if (trovato){
                    //                    trovato = false
                    //                }
                    //                else if(!trovato){
                    //                    poiData!.append(poiData1[i])
                    //                    poiCache.insert(poiData!.last!, forKey: (poiData!.last?.UUID)!)
                    //                    delegate.addAnnotation(for: poiData1[i])
                    //                }
                    
                    //                for poi in poiData!{
                    //                    if(poi.ID == poiData1[i].ID){
                    //                        trovato = true
                    //                        break
                    //                    }
                    //                }
                    
                }
                
                i = i + 1
            }
            do {
                try self.poiCache.saveToDisk(withName: "poiCache")
            }
            catch{
                print(error)
            }
        }catch {
            print(error)
        }
    }
}
