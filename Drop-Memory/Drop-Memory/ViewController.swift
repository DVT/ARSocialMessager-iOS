
//
//  ViewController.swift
//  ARKitWorkingWithWorldMapData
//
//  Created by Macbook on 8/11/18.
//  Copyright © 2018 Jayven Nhan. All rights reserved.
//

import UIKit
import ARKit
import Firebase
import CoreLocation
import FirebaseDatabase

class ViewController: UIViewController {
    
    var addButton: UIButton!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var scene: SCNScene!
    var storageRef: StorageReference!
    var anchor: StorageReference!
    let locationManager: CLLocationManager = CLLocationManager()
    var fileName: String = ""
    
    var ref: DatabaseReference!

    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
    var anchorsArray: [MessageAnchor] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        configureLighting()
        //addTapGestureToSceneView()
        setScene()
        storageRef = Storage.storage().reference()
        ref = Database.database().reference()
        print("bucket \(storageRef.bucket)")
        //<<
        //Location Delegates
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
//        locationManager.startUpdatingHeading()  //for angle
        //locationManager.requestLocation()
    }
    
    func setScene() {
        scene = SCNScene()
        addButton = UIButton()
        
        addButton.backgroundColor = .black
        addButton.setTitle("Add memory", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        
        self.view.addSubview(addButton)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        addButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        addButton.bottomAnchor.constraint(equalTo: label.topAnchor, constant: 0).isActive = true
        
        sceneView.scene = scene
    }
    
    //3d plane with text
    func generateLabelNode (anchor: ARAnchor) -> SCNNode {
        
        for myAnchor in anchorsArray {
            if myAnchor.ID == anchor.identifier {
                TextHelper.message = myAnchor.message
                break
            }
        }
        
        let text = SCNText(string: TextHelper.message, extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 1)
        text.flatness = 0.005
        let textNode = SCNNode(geometry: text)
        let fontScale: Float = 0.01
        textNode.scale = SCNVector3(fontScale, fontScale, fontScale)
        
        let (min, max) = (text.boundingBox.min, text.boundingBox.max)
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        
        let width = (max.x - min.x) * fontScale
        let height = (max.y - min.y) * fontScale
        let plane = SCNPlane(width: CGFloat(width + 0.01), height: CGFloat(height + 0.01))
        let planeNode = SCNNode(geometry: plane)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.8)
        planeNode.geometry?.firstMaterial?.isDoubleSided = true
        planeNode.position = textNode.position
        textNode.eulerAngles = planeNode.eulerAngles
        
        //rotation
        if let currentFrame =  sceneView.session.currentFrame {
            planeNode.transform = SCNMatrix4MakeRotation(currentFrame.camera.eulerAngles.y, 0 , 1, 0)
        } else {
            planeNode.transform = SCNMatrix4MakeRotation(anchor.transform.columns.1.w, 0 , 1, 0)
        }
        
        //translation
        if let planeAnchor = anchor as? ARPlaneAnchor {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, planeAnchor.center.x, 0, planeAnchor.center.z)
        } else {
            planeNode.transform = SCNMatrix4Translate(planeNode.transform, anchor.transform.translation.x, 0, anchor.transform.translation.z)
        }
        planeNode.addChildNode(textNode)
        return planeNode
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetTrackingConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    @IBAction func resetBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        resetTrackingConfiguration()
    }
    
    @IBAction func saveBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        sceneView.session.getCurrentWorldMap { (worldMap, error) in
            guard let worldMap = worldMap else {
                return self.setLabel(text: "Error getting current world map.")
            }
            
            do {
                self.anchor = self.storageRef.child(self.fileName) //<<
                try self.archive(worldMap: worldMap)
                DispatchQueue.main.async {
                    self.setLabel(text: "World map is saved.")
                }
            } catch {
                fatalError("Error saving world map: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func loadBarButtonItemDidTouch(_ sender: UIBarButtonItem) {
        let _ = retrieveWorldMapData(from: worldMapURL)
    }
    
    func loadStuff(worldMap: ARWorldMap) {
        resetTrackingConfiguration(with: worldMap)
    }
    
    func resetTrackingConfiguration(with worldMap: ARWorldMap? = nil) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical, .horizontal]
        
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        if let worldMap = worldMap {
            configuration.initialWorldMap = worldMap
            setLabel(text: "Found saved world map.")
        } else {
            setLabel(text: "Move camera around to map your surrounding space.")
        }
        
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.session.run(configuration, options: options)
        let childNodes = scene.rootNode.childNodes
        for node in childNodes {
            node.removeFromParentNode()
        }
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap) throws {
        anchor = storageRef.child("\(fileName)")
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        anchor.putData(data)
    }
    
    func retrieveWorldMapData(from url: URL) -> Data? {
        anchor = storageRef.child("\(fileName)")
        do {
            
            self.anchor.getData(maxSize: 2 * 1024 * 1024) { data, error in
                guard let data = data, let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
                    let worldMap: ARWorldMap = unarchievedObject else { return }
                
                self.ref.child(self.fileName.replacingOccurrences(of: ".", with: "_"))
                    .observeSingleEvent(of: DataEventType.value) { (snapshot) in
                        
                        snapshot.children.forEach({ (child) in
                            let dataSnap = child as! DataSnapshot
                            let c = dataSnap.value as! [String : String]
                            self.anchorsArray.append(MessageAnchor(id: UUID(uuidString:c["anchorID"]!)! , message:c["text"]!))

                        })
                        
                        if self.anchorsArray.count == snapshot.childrenCount {
                            self.loadStuff(worldMap: worldMap)
                        }
                }
                print("world map download error: \(error)")
            }
            return nil
        } catch {
            self.setLabel(text: "Error retrieving world map data.")
            return nil
        }
    }
    
    func unarchive(worldMapData data: Data) -> ARWorldMap? {
        guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data),
            let worldMap: ARWorldMap = unarchievedObject else { return nil }
        return worldMap
    }
    
    @objc func buttonTap() {
        let alert = UIAlertController(title: "Drop a Memory", message: "Enter a message", preferredStyle: .alert)
        
        //2. Add the text field. You can configure it however you need.
        alert.addTextField { (textField) in
            textField.text = ""
        }
        
        // 3. Grab the value from the text field, and print it when the user clicks OK.
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak alert] (_) in
            let textField = alert?.textFields![0] // Force unwrapping because we know it exists.
            TextHelper.message = textField!.text!
            //self.theRest()
            
            guard let hitTestResult = self.sceneView.hitTest(self.addButton.frame.origin, types: [.featurePoint, .estimatedHorizontalPlane, .estimatedVerticalPlane, .existingPlane, .existingPlaneUsingExtent, .existingPlaneUsingGeometry]).first
                else { return }
            let anchor = ARAnchor(transform: hitTestResult.worldTransform)
            let model = AnchorTextModel(fileName: self.fileName, anchorID: anchor.identifier.uuidString , text: TextHelper.message)
            //let hitVector = SCNMatrix4FromGLKMatrix4(hitTransform)
            //            let vector3 = SCNVector3()
            print("the messgage model is: \(model)")
            
            self.ref.child(self.fileName.replacingOccurrences(of: ".", with: "_")).childByAutoId().setValue(["fileName": model.fileName,
                "anchorID": model.anchorID,
                "text": model.text])
            self.sceneView.session.add(anchor: anchor)
            print("SAVED ID: \(anchor.identifier)")
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { [weak alert] (_) in
        }))
        
        let vc = self.view?.window?.rootViewController
        if vc?.presentedViewController == nil {
            vc?.present(alert, animated: true, completion: nil)
        }
    }
    
    
    func theRest() {
        
        guard let sceneView = self.view as? ARSKView else {
            return
        }
        
        // Create anchor using the camera's current position
        if let currentFrame = sceneView.session.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
        }
    }
    
}


extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard !(anchor is ARPlaneAnchor) else { return }
        if let currentFrame = sceneView.session.currentFrame {
            let node = generateLabelNode(anchor: anchor)
            DispatchQueue.main.async {
                self.scene.rootNode.addChildNode(node)
            }
        }
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

extension UIColor {
    open class var transparentWhite: UIColor {
        return UIColor.white.withAlphaComponent(0.70)
    }
}

