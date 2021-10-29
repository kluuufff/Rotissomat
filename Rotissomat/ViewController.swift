//
//  ViewController.swift
//  Rotissomat
//
//  Created by Надежда Возна on 29.10.2021.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var mainCameraView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var mainScreen: UIView!
    @IBOutlet weak var previewImage: UIImageView!
    
    private var captureSession = AVCaptureSession()
    private var previewLayer = AVCaptureVideoPreviewLayer()
    private var currentCaptureDevice: AVCaptureDevice?
    private var outputCapturePhoto = AVCaptureStillImageOutput()
    private var infoMode = false
    private var ghostMode = false
    private var flashMode = false
    private var cameraModeFlag = false
    private var totalSeconds = Int()
    private var timer: Timer?
    private var overlay = UIView()
    private var tempBrightness: CGFloat = UIScreen.main.brightness
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainCameraView.layer.isOpaque = true
        previewImage.layer.opacity = 1.0
        checkCameraPermissions()
        setUpCamera()
        timeLabel.textColor = .white
        let gestures = UILongPressGestureRecognizer(target: self,
                                                    action: #selector(startRecord))
        self.mainScreen.addGestureRecognizer(gestures)
        overlay = createOverlay(frame: view.frame,
                                xOffset: view.frame.midX,
                                yOffset: view.frame.midY,
                                radius: view.frame.width * 45 / 100)
        overlay.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = 10
        blurView.contentView.addSubview(timeLabel)
        view.addSubview(blurView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = self.mainCameraView.bounds
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @objc func startRecord(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            timeLabel.textColor = .red
            timer = Timer.scheduledTimer(timeInterval: 1.0,
                                         target: self,
                                         selector: #selector(recordTime),
                                         userInfo: nil,
                                         repeats: true)
        } else {
            timeLabel.textColor = .white
            timer?.invalidate()
        }
    }
    
    @objc func recordTime() {
        var minutes: Int
        var seconds: Int
        if totalSeconds == 0 {
            timer?.invalidate()
        }
        totalSeconds = totalSeconds + 1
        minutes = (totalSeconds % 3600) / 60
        seconds = (totalSeconds % 3600) % 60
        timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.setUpCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        @unknown default:
            fatalError()
        }
    }
    
    private func getFrontCamera() -> AVCaptureDevice?{
        let videoDevices = AVCaptureDevice.devices(for: AVMediaType.video)
        var result: AVCaptureDevice!
        for device in videoDevices {
            let device = device
            if device.position == AVCaptureDevice.Position.front {
                result = device
            }
        }
        return result
    }
    
    private func getBackCamera() -> AVCaptureDevice{
        return AVCaptureDevice.default(for: AVMediaType.video)!
    }
    
    private func setUpCamera() {
        var error: NSError?
        var input: AVCaptureDeviceInput?
        captureSession = AVCaptureSession()
        currentCaptureDevice = (cameraModeFlag ? getFrontCamera() : getBackCamera())
        do {
            input = try AVCaptureDeviceInput(device: currentCaptureDevice!)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
//        for i: AVCaptureDeviceInput in (self.captureSession.inputs as! [AVCaptureDeviceInput]){
//            self.captureSession.removeInput(i)
//        }
        if error == nil && captureSession.canAddInput(input!) {
            captureSession.addInput(input!)
            if let device = AVCaptureDevice.default(for: .video) {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if captureSession.canAddInput(input) {
                        captureSession.addInput(input)
                    }
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer.videoGravity = .resizeAspectFill
                    previewLayer.connection?.videoOrientation = .portrait
                    self.mainCameraView.layer.addSublayer(previewLayer)
                    self.mainCameraView.addSubview(overlay)
                    DispatchQueue.main.async {
                        self.captureSession.startRunning()
                    }
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @IBAction func ghostButtonAction(_ sender: UIButton) {
        outputCapturePhoto.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        outputCapturePhoto.isHighResolutionStillImageOutputEnabled = false
        UIView.animate(withDuration: 0.1,
                       animations: {
            sender.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        },
                       completion: { _ in
            UIView.animate(withDuration: 0.2) { [self] in
                if self.ghostMode {
                    sender.setImage(UIImage(named: "ghost-on"),
                                    for: .normal)
                    previewImage.layer.opacity = 0.0
                    previewImage.image = nil
                    self.ghostMode = false
                } else {
                    sender.setImage(UIImage(named: "ghost-off"),
                                    for: .normal)
                    if captureSession.canAddOutput(outputCapturePhoto) {
                        captureSession.addOutput(outputCapturePhoto)
                    }
                    DispatchQueue.main.async {
                        let videoConnection = outputCapturePhoto.connection(with: AVMediaType.video)
                        if videoConnection != nil {
                            outputCapturePhoto.captureStillImageAsynchronously(from: outputCapturePhoto.connection(with: AVMediaType.video)!)
                            { (imageDataSampleBuffer, error) -> Void in
                                if let image = UIImage(data: AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)!) {
                                    previewImage.layer.opacity = 0.6
                                    self.previewImage.image = image
//                                    UIImageWriteToSavedPhotosAlbum(self.previewImage.image!, self, nil, nil)
                                }
                            }
                        }
                    }
                    self.ghostMode = true
                }
                sender.transform = CGAffineTransform.identity
            }
        })
    }
    
    private func createOverlay(frame: CGRect,
                               xOffset: CGFloat,
                               yOffset: CGFloat,
                               radius: CGFloat) -> UIView {
        let overlayView = UIView(frame: frame)
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: xOffset, y: yOffset),
                    radius: radius,
                    startAngle: 0.0,
                    endAngle: 2.0 * .pi,
                    clockwise: false)
        path.addRect(CGRect(origin: .zero, size: overlayView.frame.size))
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        return overlayView
    }
    
    private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
                else { return }
        guard device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
            }
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    @IBAction func flashButtonAction(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1,
                       animations: {
            sender.transform = CGAffineTransform(scaleX: 1.3, y: 1.3) },
                       completion: { _ in
            UIView.animate(withDuration: 0.2) {
                if self.flashMode {
                    sender.setImage(UIImage(named: "flash-off"),
                                    for: .normal)
                    if self.cameraModeFlag {
                        self.overlay.backgroundColor = .white.withAlphaComponent(0.0)
                        UIScreen.main.brightness = self.tempBrightness
                    } else {
                        self.toggleFlash()
                    }
                    self.flashMode = false
                } else {
                    sender.setImage(UIImage(named: "flash-on"),
                                    for: .normal)
                    if self.cameraModeFlag {
                        self.overlay.backgroundColor = .white.withAlphaComponent(1.0)
                        self.tempBrightness = UIScreen.main.brightness
                        UIScreen.main.brightness = CGFloat(1.0)
                    } else {
                        self.toggleFlash()
                    }
                    self.flashMode = true
                }
                sender.transform = CGAffineTransform.identity
            }
        })
    }
    
    @IBAction func modeButtonAction(_ sender: UIButton) {
        let blurView = UIVisualEffectView(frame: mainCameraView.bounds)
        blurView.effect = UIBlurEffect(style: .light)
        mainCameraView.addSubview(blurView)
        UIView.animate(withDuration: 0.2,
                       animations: {
            sender.transform = CGAffineTransform(scaleX: 1.3, y: 1.3) },
                       completion: { _ in
            UIView.animate(withDuration: 0.3) {
                if self.cameraModeFlag {
                    sender.setImage(UIImage(named: "selfie"),
                                    for: .normal)
                    self.cameraModeFlag.toggle()
                    self.setUpCamera()
                } else {
                    sender.setImage(UIImage(named: "rear"),
                                    for: .normal)
                    self.cameraModeFlag.toggle()
                    self.setUpCamera()
                }
                sender.transform = CGAffineTransform.identity
            }
        })
    }
}
