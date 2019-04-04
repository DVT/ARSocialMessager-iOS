
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
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var label: UILabel!
    
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var storageRef: StorageReference!
    var anchor: StorageReference!
    let locationManager: CLLocationManager = CLLocationManager()
    var fileName: String = ""
    
    let ref = Database.database().reference()

    var worldMapURL: URL = {
        do {
            return try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("worldMapURL")
        } catch {
            fatalError("Error getting world map URL from document directory.")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        configureLighting()
        addTapGestureToSceneView()
        setScene()
        scene.rootNode.addChildNode(addCameraNode())
        storageRef = Storage.storage().reference()
        print("bucket \(storageRef.bucket)")
//        anchor = storageRef.child("Test/\()")
        locationManager.requestLocation() //<<
        //Location Delegates
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
//        locationManager.startUpdatingHeading()  //for angle
    }
    
    func setScene() {
        scene = SCNScene()
        sceneView.scene = scene
    }
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didReceiveTapGesture(_:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didReceiveTapGesture(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        guard let hitTestResult = sceneView.hitTest(location, types: [.featurePoint, .estimatedHorizontalPlane, .estimatedVerticalPlane, .existingPlane]).first
            else { return }
        let anchor = ARAnchor(transform: hitTestResult.worldTransform)
        sceneView.session.add(anchor: anchor)
        
    }

    func addCameraNode() -> SCNNode {
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
        return cameraNode
    }
    
    
    func generateLabelNode (anchor: ARAnchor) -> SCNNode {
        let label = SCNText(string: "Hello", extrusionDepth: 0.01)
        label.font = UIFont (name: "Arial", size: 1)
        label.firstMaterial!.diffuse.contents = UIColor.red
        let labelNode = SCNNode(geometry: label)
        var x = anchor.transform.columns.3.x + Float.random(in: -0.05...0.05)
        var y = anchor.transform.columns.3.y + Float.random(in: -0.05...0.05)
        var z = anchor.transform.columns.3.z - Float.random(in: 0.1...0.5)
        labelNode.position = SCNVector3(x: x, y: y, z: z)
        return labelNode
    }
    
    func generateBoxNode (anchor: ARAnchor) -> SCNNode {
        let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0.0)
        box.firstMaterial!.diffuse.contents = UIColor.red
        var boxNode = SCNNode(geometry: box)
        var x = anchor.transform.columns.3.x + Float.random(in: 0...0.5)
        var y = anchor.transform.columns.3.y + Float.random(in: 0...0.05)
        var z = anchor.transform.columns.3.z - Float.random(in: 10...15)
        boxNode.position = SCNVector3(x: x, y: y, z: z)
        return boxNode
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
        addCameraNode()
    }
    
    func setLabel(text: String) {
        label.text = text
    }
    
    func archive(worldMap: ARWorldMap) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        anchor.putData(data)
        //try data.write(to: self.worldMapURL, options: [.atomic])
    }
    
    func retrieveWorldMapData(from url: URL) -> Data? {
        do {
            anchor.getData(maxSize: 2 * 1024 * 1024) { data, error in
                guard let unarchievedObject = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data!),
                    let worldMap: ARWorldMap = unarchievedObject else { return }
                self.loadStuff(worldMap: worldMap)
            }
            
            //let data =  try Data(contentsOf: self.worldMapURL)
            
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
    
}


extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //guard !(anchor is ARPlaneAnchor) else { return }
        let node = generateLabelNode(anchor: anchor)
        DispatchQueue.main.async {
            self.scene.rootNode.addChildNode(node)
            self.cameraNode.removeFromParentNode()
            self.addCameraNode()
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

