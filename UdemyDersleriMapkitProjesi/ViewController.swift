//
//  ViewController.swift
//  UdemyDersleriMapkitProjesi
//
//  Created by Apple on 24.07.2020.
//  Copyright © 2020 erdogan. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation //konum almak için gerekli
import CoreData //database için

class ViewController: UIViewController {


    @IBOutlet weak var mapView: MKMapView!
    var locationManager = CLLocationManager() //konumla alakalı adımlarda kullanılır lot long gibi

    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var txtFieldTitle: UITextField!
    @IBOutlet weak var txtFieldSubTitle: UITextField!
    var choosenCoordinate = CLLocationCoordinate2D()
    var selectedTitle = ""
    var selectedTitleID:UUID?
    var annotationTitle = ""
    var annotationSubTitle = ""
    var annotationlatitude = Double()
    var annotationLongitude = Double()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        btnSave.layer.cornerRadius = btnSave.frame.height/2
        txtFieldTitle.layer.cornerRadius = txtFieldTitle.frame.height/2
        txtFieldTitle.clipsToBounds = true
        txtFieldSubTitle.layer.cornerRadius = txtFieldSubTitle.frame.height/2
        txtFieldSubTitle.clipsToBounds = true

        mapView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest //konum doğruluğu en iyi olsun (pili fazla harcar)
        locationManager.requestWhenInUseAuthorization() //sadece uygulama kullanılırken konum istenecek
        locationManager.startUpdatingLocation() //kullanıcı konumu alınmaya başlar
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(chooseLocation(gestureRecognizer:))) // kullanıcı uzun süre basınca tetiklenecek
        gestureRecognizer.minimumPressDuration = 3 //3 saniye basınca metot tetiklenir
        mapView.addGestureRecognizer(gestureRecognizer)
        
        if selectedTitle != "" {
            //coreData
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let context = appDelegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Places")
            let idString = selectedTitleID!.uuidString
            fetchRequest.predicate = NSPredicate(format: "id = %@", idString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do{
                let results = try context.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject]{
                        if let title = result.value(forKey: "title") as? String{
                            self.annotationTitle = title
                            if let subTitle = result.value(forKey: "subTitle") as? String{
                                self.annotationSubTitle = subTitle
                                if let latitude = result.value(forKey: "latitude") as? Double {
                                    self.annotationlatitude = latitude
                                    if let longitude = result.value(forKey: "longitude") as? Double{
                                        self.annotationLongitude = longitude
                                        let annotation = MKPointAnnotation()
                                        annotation.title = annotationTitle
                                        annotation.subtitle = annotationSubTitle
                                        let coordinate = CLLocationCoordinate2D(latitude: annotationlatitude, longitude: annotationLongitude)
                                        annotation.coordinate = coordinate
                                        mapView.addAnnotation(annotation)
                                        txtFieldTitle.text = annotationTitle
                                        txtFieldSubTitle.text = annotationSubTitle
                                        locationManager.stopUpdatingLocation() //kullanıcı yer değiştirsede açtığı annotation yeri kalsın diye güncelleme kapatılıyor
                                        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        let region = MKCoordinateRegion(center: coordinate, span: span)
                                        mapView.setRegion(region, animated: true)
                                        
                                    }
                                }
                            }
                        }
                    }
                }
            } catch{
                print("Error")
            }
            
        } else{
            //addNewData
        }
        
    }
     
    @objc func chooseLocation(gestureRecognizer: UILongPressGestureRecognizer){
        if gestureRecognizer.state == .began { // gestureRecognizer başladı mı?
            // dokunulan noktanın koordinatları alınır
            let touchedLocation = gestureRecognizer.location(in: self.mapView)
            let touchedCoordinate = self.mapView.convert(touchedLocation, toCoordinateFrom: self.mapView)
            self.choosenCoordinate = touchedCoordinate
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchedCoordinate
            annotation.title = txtFieldTitle.text
            annotation.subtitle = txtFieldSubTitle.text
            self.mapView.addAnnotation(annotation)
            
            
        }
    }
    
    @IBAction func btnSaveTapped(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: "Places", into: context)
        
        newPlace.setValue(txtFieldTitle.text, forKey: "title")
        newPlace.setValue(txtFieldSubTitle.text, forKey: "subTitle")
        newPlace.setValue(choosenCoordinate.latitude, forKey: "latitude")
        newPlace.setValue(choosenCoordinate.longitude, forKey: "longitude")
        newPlace.setValue(UUID(), forKey: "id")
        txtFieldTitle.text = ""
        txtFieldSubTitle.text = ""
        
        do{
            try context.save()
            print("Success")
        } catch{
            print("Error")
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("newPlace"), object: nil)
        navigationController?.popViewController(animated: true)
        
    }
    

}

extension ViewController: MKMapViewDelegate { //protokollerden fonk. kullanmamızı sağlar. Otomatik tektiklenen fonk.lar
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation{
            return nil
        }
        
        let reuseID = "myAnnotationID"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKPinAnnotationView
        
        if pinView == nil{
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView?.canShowCallout = true //baloncukla birllikte ekstra bilgi gösterdiğimiz yer
            pinView?.tintColor = UIColor.black
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if selectedTitle != "" {
            // CLGeocoder koordinatlar ve yerler arasında bağlantı kurmaya yarar
            let requestLocation = CLLocation(latitude: annotationlatitude, longitude: annotationLongitude)
            
            //navigasyonu çalıştırır
            CLGeocoder().reverseGeocodeLocation(requestLocation) { (placemarks, error) in
                //closure yapısı callback function sonucunda bir şey döner
                if let placemark = placemarks {
                    if placemark.count > 0 {
                        // navigasyonu çalışırabilmek için gerekli obje mapitem için gerekli
                        let newPlacemark = MKPlacemark(placemark: placemark[0])
                        let item = MKMapItem(placemark: newPlacemark) // nevigasyonu açmak için gerekli
                        item.name = self.annotationTitle
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] // hangi modda açılacak
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }else{ return }
            }
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // güncellenen lokasyonu dizi içerisinde verir
        if selectedTitle == ""{
            guard let location = locations.last else{ return }
            let center = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let span = MKCoordinateSpan(latitudeDelta: 0.01 , longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(region, animated: true)
        }
    }
}

