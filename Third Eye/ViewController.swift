//
//  ViewController.swift
//  Third Eye
//
//  Created by Alessandro Parisi on 2015-07-18.
//  Copyright (c) 2015 Trith Tech. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreData


var cameraFound = false
var cameraUsed = false
var apikey = "206b53c6-f0b9-44e4-ad94-88c53dee69c4"


class ViewController : UIViewController, UITextFieldDelegate, AVAudioPlayerDelegate, AVAudioRecorderDelegate, AVSpeechSynthesizerDelegate {
    
    // Create a new instance of the AVCaptureStillImageOutput class
    // in order to perform an AV capture on the camera device
    var audioPlayer: AVAudioPlayer?
    var audioRecorder: AVAudioRecorder?
    
    @IBOutlet var summaryLabel: UILabel!
    var myIndex:String = "harry"
    
    var oldString: String = ""
    
    var tookPicture = false
    
    var isRecording = false
    
    var adImage : UIImage?

    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    var summary: String? = ""
    var fullText: String? = ""
    var sentimentSentence: String? = ""
    
    @IBOutlet var captureView: UIView!
    
    var imageCaptureOutput = AVCaptureStillImageOutput()
    
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    let captureSession = AVCaptureSession()
    
    var previewLayer : AVCaptureVideoPreviewLayer?
    var panGesture : UIPanGestureRecognizer?
    var tapGesture : UITapGestureRecognizer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dirPaths =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory,
            .UserDomainMask, true)
        let docsDir = dirPaths[0] as! String
        let soundFilePath =
        docsDir.stringByAppendingPathComponent("sound1.caf")
        let soundFileURL = NSURL(fileURLWithPath: soundFilePath)
        
        

        let recordSettings =
        [AVEncoderAudioQualityKey: AVAudioQuality.Min.rawValue,
            AVEncoderBitRateKey: 16,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0]
        
        var error: NSError?
        
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord,
            error: &error)
        
        audioSession.overrideOutputAudioPort(AVAudioSessionPortOverride.Speaker, error: nil)

        if let err = error {
            println("audioSession error: \(err.localizedDescription)")
        }
        
        audioRecorder = AVAudioRecorder(URL: soundFileURL,
            settings: recordSettings as [NSObject : AnyObject], error: &error)
        
        if let err = error {
            println("audioSession error: \(err.localizedDescription)")
        } else {
            audioRecorder?.prepareToRecord()
        }
        
        cameraUsed = false
        cameraFound = false
        
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        let devices = AVCaptureDevice.devices()
        
        // Loop through all the capture devices on this phone
        for device in devices {
            // Make sure this particular device supports video
            if (device.hasMediaType(AVMediaTypeVideo)) {
                // Finally check the position and confirm we've got the back camera
                if(device.position == AVCaptureDevicePosition.Back) {
                    captureDevice = device as? AVCaptureDevice
                    
                    if captureDevice != nil {
                        cameraFound = true
                    }
                }
            }
        }
        
    }
    override func viewDidAppear(animated: Bool) {
        NSLog("viewdidappear")
        
        if cameraFound && !cameraUsed {
            cameraUsed = true
            beginSession()
        }
    }
    func takePicture() {
        tookPicture = true
        
        // Capture a photo
        if let device = captureDevice {
            // Grab the first available connection in the output chain
            if let captureConnection = imageCaptureOutput.connections[0] as? AVCaptureConnection {
                // Capture the image to imageSamplebuffer
                imageCaptureOutput.captureStillImageAsynchronouslyFromConnection(captureConnection, completionHandler: { (imageSampleBuffer, error) -> Void in
                    // Convert the sample buffer in to a jpeg representation in the form of an NSData
                    // This is suitable for writing to disk
                    if imageSampleBuffer != nil {
                        self.captureSession.stopRunning()
                        var imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                        if let img = UIImage(data: imageData) {
                            self.adImage = img
                            self.sendAd();
                            self.enableTrans();
                        }
                    }
                })
            }
        }
    }
    
    func beginSession() {
        var err : NSError? = nil
        // The capture session currently has no inputs, it's just an empty session
        // Add a new input from the captureDevice
        captureSession.addInput(AVCaptureDeviceInput(device: captureDevice, error: &err))
        
        // Check for errors setting the input
        if err != nil {
            println("error: \(err?.localizedDescription)")
        }
        
        // Set our previewLayer instance variable to be a new preview layer
        // instantiated with the captureSession
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.bounds = self.captureView.bounds
        previewLayer?.videoGravity = AVLayerVideoGravityResize
        
        // Add the layer to the view as a sublayer
        self.view.layer.addSublayer(previewLayer)
        
        // Make it fill the entire contents of the view
        previewLayer?.frame = self.captureView.layer.frame
        
        // Begin the session
        captureSession.startRunning()
        
        // Add the current session to the image output chain
        captureSession.addOutput(imageCaptureOutput)
    }
    
    var targetFocus : Float = 0.0
    
//    @IBAction func restartSession(sender: AnyObject) {
//        self.captureSession.startRunning()
//        adImage = nil
//    }
    func adjustCamera(focusPer : Float) {
        if let device = captureDevice {
            if(device.lockForConfiguration(nil)) {
                device.setFocusModeLockedWithLensPosition(focusPer, completionHandler: { (time) -> Void in
                    //
                })
                device.unlockForConfiguration()
            }
        }
    }
    
    func sendAd() {
        
        
        
            adImage!.resize(CGSize(width: 480, height: 854), completionHandler: { (resizedImage, data) -> () in
                var err: NSError?
                
                let url = NSURL(string: "https://api.idolondemand.com/1/api/sync/ocrdocument/v1")
                let request = NSMutableURLRequest(URL: url!)
                request.HTTPMethod = "POST"
                
                
                let uniqueId = NSProcessInfo.processInfo().globallyUniqueString
                var boundary:String = "----WebKitFormBoundary\(uniqueId)"
                
                var postBody:NSMutableData = NSMutableData()
                var postData:String = String()
                
                request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField:"Content-Type")
                
                postData += "--\(boundary)\r\n"
                
                postData += "Content-Disposition: form-data; name=\"apikey\"\r\n\r\n"
                postData += "\(apikey)\r\n"
                postData += "--\(boundary)\r\n"
                
                postData += "Content-Disposition: form-data; name=\"mode\"\r\n\r\n"
                postData += "scene_photo\r\n"
                postData += "--\(boundary)\r\n"
                
                postData += "Content-Disposition: form-data; name=\"file\"; filename=\"\(Int64(NSDate().timeIntervalSince1970*1000)).jpg\"\r\n"
                postData += "Content-Type: image/jpeg\r\n\r\n"
                
                postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding)!)
                postBody.appendData(data)
                
                postData = String()
                postData += "\r\n"
                postData += "\r\n--\(boundary)--\r\n"
                postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding)!)
                
                request.HTTPBody = NSData(data: postBody)
                
                
                let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error -> Void in
                    
                    if((error) != nil){
                        println(error)
                    }
                    else{
                        if let httpResponse = response as? NSHTTPURLResponse {
                            if httpResponse.statusCode == 200 {

                                if let json: Dictionary<String, AnyObject> = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &err) as? Dictionary<String, AnyObject>  {
                                    
                                    if var textObjList = json["text_block"] as? NSArray{
                                        var entireText = "";
                                        for textObj in textObjList {
                                            if var t = textObj["text"] as? String{
                                                entireText += t;
                                            }
                                        }
                                        println("------------------------------------------------------------")
                                        
                                        println(entireText);
                                        println("------------------------------------------------------------")
                                        
                                        let encodedData = entireText.dataUsingEncoding(NSUTF8StringEncoding)!
                                        let attributedOptions : [String: AnyObject] = [
                                            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                            NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding
                                        ]
                                        let attributedString = NSAttributedString(data: encodedData, options: attributedOptions, documentAttributes: nil, error: nil)!
                                        let decodedString = attributedString.string
                                        
                                        println(decodedString);
                                        
                                        self.fullText = decodedString
                                        
                                        println("----------------------------------------------")
                                        
                                        let url = "https://api.idolondemand.com/1/api/sync/analyzesentiment/v1"
                                        
                                        let data = [
                                            "apikey" : apikey,
                                            "text" : decodedString
                                        ]
                                        
                                        self.myPost(url, params: data)
                                        
                                    }
                                }
                            }
                            
                        }
                    }
                }
                task.resume()
            })
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func textToSpeech(text: String){
        myUtterance = AVSpeechUtterance(string: text)
        myUtterance.rate = 0.02
        myUtterance.volume = 1
        var voice = AVSpeechSynthesisVoice(language: "english")
        myUtterance.voice = voice
        synth.speakUtterance(myUtterance)
    }
    
    func myPost(urlStr: String, params: Dictionary<String, AnyObject>){
        var err: NSError?
        let url = NSURL(string: urlStr)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        request.HTTPBody = NSJSONSerialization.dataWithJSONObject(params, options: nil, error: &err)

        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error -> Void in
            if((error) != nil){
                println(error)
            }
            else{
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        
                        if let json: Dictionary<String, AnyObject> = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &err) as? Dictionary<String, AnyObject>  {
                            
                            println(json);
                            if let aggregate = json["aggregate"] as? Dictionary<String, AnyObject> {
                                var sentiment = aggregate["sentiment"] as? String
                                self.sentimentSentence = "This article has a " + sentiment! + " connotation."
                                
                                
                                //get Summary
                                let url = ""
                                
                                self.myPostSummary();
                            }
                        }
                    }
                }
            }
        }
        task.resume()
        
    }
    func myPostSummary(){

        var err: NSError?
        var path2 = "https://api.idolondemand.com/1/api/sync/querytextindex/v1?apikey=" + apikey + "&text="+myIndex+"&indexes="+myIndex+"&summary=quick"
        
        
        let url2 = NSURL(string: path2)
        let task2 = NSURLSession.sharedSession().dataTaskWithURL(url2!) {(data, response, error) in
            if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json: Dictionary<String, AnyObject> = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &err) as? Dictionary<String, AnyObject>  {
                        
                        var documents = json["documents"] as! Array<AnyObject>
                        var doc = documents[0] as! Dictionary<String, AnyObject>
                        self.summary = doc["summary"] as! String
                        

                                
                        //Once the label is completely invisible, set the text and fade it back in
                        self.summaryLabel.text = self.summary
                        
                        // Fade in
                        UIView.animateWithDuration(1.0, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: {
                            self.summaryLabel.alpha = 1.0
                        }, completion: nil)
                        
                        self.textToSpeech(self.sentimentSentence!)
                        self.textToSpeech(self.summary!)
                    }
                }
            }
        }
        task2.resume()
        
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        if tookPicture {
            if self.isRecording {
                self.isRecording = false
                self.stopAudio()
                self.playAudio()
            }
            else{
//                self.synth.pauseSpeakingAtBoundary(AVSpeechBoundary.Immediate)
                self.oldString = self.myUtterance.speechString
                self.synth.stopSpeakingAtBoundary(AVSpeechBoundary.Immediate)
                self.isRecording = true
                self.recordAudio()
            }
        }
        else{
            self.takePicture()
        }
    }
    
    //Change this to using HP stuff
    func playAudio() {
        
        let dirPaths =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory,
            .UserDomainMask, true)
        let docsDir = dirPaths[0] as! String
        let soundFilePath =
        docsDir.stringByAppendingPathComponent("sound1.caf")
        let soundFileURL = NSURL(fileURLWithPath: soundFilePath)
        
        let audioData = NSData(contentsOfURL: soundFileURL!)

        var err: NSError?
        let urlStr = "https://api.idolondemand.com/1/api/async/recognizespeech/v1"
        let url = NSURL(string: urlStr)
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        
        
        let uniqueId = NSProcessInfo.processInfo().globallyUniqueString
        var boundary:String = "----WebKitFormBoundary\(uniqueId)"
        
        var postBody:NSMutableData = NSMutableData()
        var postData:String = String()
        
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField:"Content-Type")
        
        postData += "--\(boundary)\r\n"
        
        postData += "Content-Disposition: form-data; name=\"apikey\"\r\n\r\n"
        postData += "\(apikey)\r\n"
        postData += "--\(boundary)\r\n"

        postData += "Content-Disposition: form-data; name=\"interval\"\r\n\r\n"
        postData += "0\r\n"
        postData += "--\(boundary)\r\n"
        
        postData += "Content-Disposition: form-data; name=\"file\"; filename=\"\(Int64(NSDate().timeIntervalSince1970*1000)).jpg\"\r\n"
        postData += "Content-Type: application/octet-stream\r\n\r\n"
        
        postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding)!)

        postBody.appendData(audioData!)
        
        postData = String()
        postData += "\r\n"
        postData += "\r\n--\(boundary)--\r\n"
        postBody.appendData(postData.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        request.HTTPBody = NSData(data: postBody)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error -> Void in
            if((error) != nil){
                println(error)
            }
            else{
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        
                        if let json: Dictionary<String, String> = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &err) as? Dictionary<String, String>  {
                            
                            println(json["jobID"])
                            var path2 = "https://api.idolondemand.com/1/job/result/" + json["jobID"]! + "?apikey=" + apikey
                            let url2 = NSURL(string: path2)
                            let task2 = NSURLSession.sharedSession().dataTaskWithURL(url2!) {(data2, response2, error2) in
                                if let httpResponse = response as? NSHTTPURLResponse {
                                    if httpResponse.statusCode == 200 {
                                        if let json2: AnyObject = NSJSONSerialization.JSONObjectWithData(data2, options: nil, error: &err) as AnyObject? {
                                            var actions = json2["actions"] as! Array<AnyObject>
                                            var action = actions[0] as! Dictionary<String, AnyObject>
                                            var result = action["result"] as! Dictionary<String, AnyObject>
                                            var document = result["document"] as! Array<AnyObject>
                                            var sentence = ""
                                            
                                            var i = 0;
                                            
                                            for object in document {
                                                if i > 1 {
                                                    var o = object as! Dictionary<String, AnyObject>
                                                    var a = "%20" + (o["content"] as! String)
                                                    sentence += a
                                                }
                                                i++;
                                            }
                                            
                                            println(sentence)
                                            
                                            self.getWiki(sentence)
                                        }
                                    }
                                }
                                
                            }
                            task2.resume()
                        }
                    }
                    
                }
            }
        }
        task.resume()
    }

    func getWiki(sentence: String){
        var err: NSError?
        var myurl = "https://api.idolondemand.com/1/api/sync/findsimilar/v1?text=" + sentence + "&apikey=" + apikey + "&summary=quick"
        let url10 = NSURL(string: myurl)
        let task3 = NSURLSession.sharedSession().dataTaskWithURL(url10!) {(data, response, error) in
            println(response)
            if((error) != nil){
                println(error)
            }
            else{
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        
                        if let json: Dictionary<String, AnyObject> = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &err) as? Dictionary<String, AnyObject>  {
                            
                            var documents = json["documents"] as! Array<AnyObject>
                            var doc = documents[0] as! Dictionary<String, AnyObject>
                            var summary = doc["summary"] as! String
                            
                            println(summary)
                            
                            self.textToSpeech(summary)
                            self.synth.continueSpeaking()
                            self.textToSpeech(" resuming, " + self.oldString)
                            
                        }
                    }
                }
            }

        }
        task3.resume()
    }
    
    func stopAudio() {
        if audioRecorder?.recording == true {
            audioRecorder?.stop()
        } else {
            audioPlayer?.stop()
        }
    }

    func recordAudio() {
        
        if audioRecorder?.recording == false {
            audioRecorder?.record()
        }
    }

    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer!, error: NSError!) {
        println("Audio Play Decode Error")
    }

    func audioRecorderDidFinishRecording(recorder: AVAudioRecorder!, successfully flag: Bool) {
    }
    
    func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder!, error: NSError!) {
        println("Audio Record Encode Error")
    }
    
    func enableTrans(){
        //only apply the blur if the user hasn't disabled transparency effects
        if !UIAccessibilityIsReduceTransparencyEnabled() {
            self.view.backgroundColor = UIColor.clearColor()
            let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = self.view.bounds
            self.view.addSubview(blurEffectView) //if you have more UIViews on screen, use insertSubview:belowSubview: to place it underneath the lowest view instead
            
            //add auto layout constraints so that the blur fills the screen upon rotating device
            blurEffectView.setTranslatesAutoresizingMaskIntoConstraints(false)
            self.view.addConstraint(NSLayoutConstraint(item: blurEffectView, attribute: NSLayoutAttribute.Top, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: blurEffectView, attribute: NSLayoutAttribute.Bottom, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Bottom, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: blurEffectView, attribute: NSLayoutAttribute.Leading, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Leading, multiplier: 1, constant: 0))
            self.view.addConstraint(NSLayoutConstraint(item: blurEffectView, attribute: NSLayoutAttribute.Trailing, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Trailing, multiplier: 1, constant: 0))
        } else {
            self.view.backgroundColor = UIColor.blackColor()
        }
    }

}

extension UIImage {
    public func resize(size:CGSize, completionHandler:(resizedImage:UIImage, data:NSData)->()) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), { () -> Void in
            var newSize:CGSize = size
            let rect = CGRectMake(0, 0, newSize.width, newSize.height)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            self.drawInRect(rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let imageData = UIImageJPEGRepresentation(newImage, 0.5)
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completionHandler(resizedImage: newImage, data:imageData)
            })
        })
    }
}