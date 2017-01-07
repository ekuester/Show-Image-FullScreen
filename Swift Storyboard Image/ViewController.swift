//
//  ViewController.swift
//  Swift Storyboard Image
//
//  show an image fitted to screen size, full screen mode is possible
//
//  Created by Erich Küster on July 31, 2016
//  Copyright © 2016 Erich Küster. All rights reserved.
//

import Cocoa
import Foundation
import ZipZap

// before the latest Swift 3, you could compare optional values
// Swift migrator solves that problem by providing a custom < operator
//which takes two optional operands and therefore "restores" the old behavior.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


class ViewController: NSViewController, NSWindowDelegate {

    var defaultSession: URLSession!

    var closeZIPItem: NSMenuItem!
    var entryIndex: Int = -1
    var pageIndex: Int = 0
    var previousUrlIndex = -1
    var urlIndex: Int = -1

    var imageArchive: ZZArchive? = nil
    var imageBitmaps = [NSImageRep]()
    var imageURLs = [URL]()
    var imageSubview: NSImageView!

    var directoryURL: URL!
    var recentItemsObserver: NSObjectProtocol!
    var inFullScreen: Bool = false
    var mainFrame: NSRect!
    var sharedDocumentController: NSDocumentController!
    var slidesTimer: Timer? = nil
    var showSlides = false
    var viewFrameOrigin: NSPoint = NSZeroPoint
    var viewFrameSize: NSSize = NSZeroSize
    var workDirectoryURL: URL!
    var zipIsOpen: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.wantsLayer = true
        if let view = self.view.subviews.first {
            imageSubview = view as! NSImageView
            imageSubview.removeFromSuperviewWithoutNeedingDisplay()
        }
        let config = URLSessionConfiguration.default
        self.defaultSession = URLSession(configuration: config)
        mainFrame = NSScreen.main()?.frame
        // find menu item "Close ZIP"
        let fileMenu = NSApp.mainMenu!.item(withTitle: "File")
        let fileMenuItems = fileMenu?.submenu?.items
        for item in fileMenuItems! {
            if (item.title == "Close ZIP") {
                closeZIPItem = item
            }
        }
        let presentationOptions: NSApplicationPresentationOptions = [.hideDock, .autoHideMenuBar]
        NSApp.presentationOptions = NSApplicationPresentationOptions(rawValue: presentationOptions.rawValue)
        sharedDocumentController = NSDocumentController.shared()
        // set user's directory as starting point of search
        let userDirectoryPath: NSString = "~"
        let userDirectoryURL = URL(fileURLWithPath: userDirectoryPath.expandingTildeInPath)
        workDirectoryURL = userDirectoryURL.appendingPathComponent("Pictures", isDirectory: true)
        // notification if file from recent documents should be opened
        recentItemsObserver = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "com.image.openfile"), object: nil, queue: nil, using: openData)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.layer?.backgroundColor = NSColor.black.cgColor
        // now window exists
        view.window!.delegate = self
        processImages()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            Swift.print("inside didSet of representedObject")
        }
    }

    override func viewDidDisappear() {
        NotificationCenter.default.removeObserver(recentItemsObserver)
    }

    func processImages() {
        if (urlIndex < 0) {
            // load new images from NSOpenPanel
            // generate File Open Dialog class
            let imageDialog: NSOpenPanel = NSOpenPanel()
            imageDialog.title = NSLocalizedString("Select image file", comment: "title of open panel")
            let imageFile = ""
            imageDialog.nameFieldStringValue = imageFile
            imageDialog.directoryURL = workDirectoryURL
            imageDialog.allowedFileTypes = ["bmp","eps","jpg","jpeg","pdf","png","tif","tiff", "zip"]
            imageDialog.allowsMultipleSelection = true;
            imageDialog.canChooseDirectories = false;
            imageDialog.canCreateDirectories = false;
            imageDialog.canChooseFiles = true;
            imageDialog.beginSheetModal(for: view.window!, completionHandler: { response in
                if response == NSFileHandlingPanelOKButton {
                    // NSFileHandlingPanelOKButton is Int(1)
                    self.urlIndex = 0
                    self.workDirectoryURL = (imageDialog.url?.deletingLastPathComponent())!
                    self.zipIsOpen = false
                    self.imageURLs = imageDialog.urls
                    self.processImages()
                }
//                self.urlIndex = self.previousUrlIndex
            })
        }
        if (urlIndex >= 0) {
            previousUrlIndex = urlIndex
            if zipIsOpen {
                imageViewWithArchiveEntry()
                return
            }
            // process images from existing URL(s)
            let actualURL = imageURLs[urlIndex]
            sharedDocumentController.noteNewRecentDocumentURL(actualURL)
            let fileType = actualURL.pathExtension
            switch fileType {
            case "zip":
                // valid URL decodes zip file
                do {
                    entryIndex = 0
                    imageArchive = try ZZArchive(url: actualURL)
                    closeZIPItem.isEnabled = true
                    zipIsOpen = true
                    imageViewWithArchiveEntry()
                } catch let error as NSError {
                    entryIndex = -1
                    Swift.print("ZipZap error: could not open archive in \(error.domain)")
                }
            default:
                imageViewfromURLRequest(actualURL)
            }
        }
    }

    func imageViewWithArchiveEntry() {
        let entry = imageArchive!.entries[entryIndex]
        do {
            let zipData = try entry.newData()
            self.fillBitmapsWithData(zipData)
            if (imageViewWithBitmap()) {
                view.window!.title = (entry.fileName)
            }
        } catch let error as NSError {
            Swift.print("Error: no valid data in \(error.domain)")
        }
    }

// look also at <https://blog.alexseifert.com/2016/06/18/resize-an-nsimage-proportionately-in-swift/>
    func fitImageIntoMainFrameRespectingAspectRatio(_ size: NSSize) -> NSSize {
        var frameOrigin = NSZeroPoint
        var frameSize = mainFrame.size
        // calculate aspect ratios
        let imageSize = size
        // calculate aspect ratios
        let mainRatio = frameSize.width / frameSize.height
        let imageRatio = imageSize.width / imageSize.height
        // fit view frame into main frame
        if (mainRatio > imageRatio) {
            // portrait, scale maxWidth
            let innerWidth = frameSize.height * imageRatio
            frameOrigin.x = (frameSize.width - innerWidth) / 2.0
            frameSize.width = innerWidth
        }
        else {
            // landscape, scale maxHeight
            let innerHeight = frameSize.width / imageRatio
            frameOrigin.y = (frameSize.height - innerHeight) / 2.0
            frameSize.height = innerHeight
        }
        viewFrameOrigin = frameOrigin
        viewFrameSize = frameSize
        return frameSize
    }

    func imageViewfromURLRequest(_ url: URL) {
        let urlRequest: URLRequest = URLRequest(url: url)
        let task = defaultSession.dataTask(with: urlRequest, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if error != nil {
                Swift.print("error from data task: \(error!.localizedDescription) in \((error as! NSError).domain)")
                return
            }
            else {
                DispatchQueue.main.async {
                    self.fillBitmapsWithData(data!)
                    if (self.imageViewWithBitmap()) {

                        self.view.window!.setTitleWithRepresentedFilename(url.lastPathComponent)
                    }
                }
            }
        }) // as! (Data?, URLResponse?, Error?) -> Void)
        task.resume()
    }

    func drawPDFPageInImage(_ page: CGPDFPage) -> NSImageRep? {
        // adapted from <https://ryanbritton.com/2015/09/correctly-drawing-pdfs-in-cocoa/>
        // Start by getting the crop box since only its contents should be drawn
        let cropBox = page.getBoxRect(.cropBox)
        
        let rotationAngle = page.rotationAngle
        let angleInRadians = Double(-rotationAngle) * (M_PI / 180)
        var transform = CGAffineTransform(rotationAngle: CGFloat(angleInRadians))
        let rotatedCropRect = cropBox.applying(transform);
        // we set manually the size scaled by 300 / 72 dpi
        let scale = CGFloat(4.1667)
        // instead of figuring out the closest size we can draw the PDF at
        // that's no larger than drawingSize
        //let bestSize = fitImageIntoMainFrameRespectingAspectRatio(rotatedCropRect.size)
        let bestSize = CGSize(width: cropBox.width*scale, height: cropBox.height*scale)
        let bestFit = CGRect(x: 0.0, y: 0.0, width: bestSize.width, height: bestSize.height)
        let scaleX = bestFit.width / rotatedCropRect.width
        let scaleY = bestFit.height / rotatedCropRect.height
        
        let width = Int(bestFit.width)
        let height = Int(bestFit.height)
        let bytesPerRow = (width * 4 + 0x0000000F) & ~0x0000000F
        //Create the drawing context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let context =  CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: (bitmapInfo))
        // Fill the background color
        context?.setFillColor(NSColor.white.cgColor)
        context?.fill(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        
        if (scaleY > 1) {
            // Since CGPDFPageGetDrawingTransform won't scale up, we need to do it manually
            transform = transform.scaledBy(x: scaleX, y: scaleY)
        }
        
        context?.concatenate(transform)
        
        // Clip the drawing to the CropBox
        context?.addRect(cropBox)
        context?.clip();
        
        context?.drawPDFPage(page);
        
        let image = context?.makeImage()
        return NSBitmapImageRep(cgImage: image!)
    }

    func fillBitmapsWithData(_ graphicsData: Data) {
        // generate representation(s) for image
        if (imageBitmaps.count > 0) {
            imageBitmaps.removeAll(keepingCapacity: false)
        }
        pageIndex = 0
        imageBitmaps = NSBitmapImageRep.imageReps(with: graphicsData)
        if (imageBitmaps.count == 0) {
            // no valid bitmaps, try EPS ( contains always only one page )
            if (NSEPSImageRep(data: graphicsData) != nil) {
                var pdfData = NSMutableData()
                let provider = CGDataProvider(data: graphicsData as CFData)
                let consumer = CGDataConsumer(data: pdfData as CFMutableData)
                var callbacks = CGPSConverterCallbacks()
                let converter = CGPSConverter(info: nil, callbacks: &callbacks, options: [:] as CFDictionary)
                let converted = converter!.convert(provider!, consumer: consumer!, options: [:] as CFDictionary)
                let pdfProvider = CGDataProvider(data: pdfData as CFData)
                let document = CGPDFDocument(pdfProvider!)
                // EPS contains always only one page
                if let page = document?.page(at: 1) {
                    if let imageRep = drawPDFPageInImage(page) {
                        imageBitmaps.append(imageRep)
                    }
                }
/*                let boundingBox = imageRep.boundingBox
                // scale by 300 / 72 dpi = 4.16...
                let scale = CGFloat(4.1667)
                imageRep.pixelsWide = Int(boundingBox.width * scale)
                imageRep.pixelsHigh = Int(boundingBox.height * scale)
                let image = NSImage()
                image.addRepresentation(imageRep)
                imageBitmaps.append(image.representations.first!) */
            }
            // at last translate PDFImageRep to BitmapImageRep if possible
            else {
                let provider = CGDataProvider(data: graphicsData as CFData)
                guard let document = CGPDFDocument(provider!) else {
                    return
                }
                let count = document.numberOfPages
                // go through pages
                for i in 1 ... count {
                    if let page = document.page(at: i) {
                        if let imageRep = drawPDFPageInImage(page) {
                            imageBitmaps.append(imageRep)
                        }
                    }
                }
            }
        }
    }

    func imageViewWithBitmap() -> Bool {
        // valid image bitmap, now look if subview contains data
        if (imageSubview != nil) {
            imageSubview?.removeFromSuperviewWithoutNeedingDisplay()
        }
        if (imageBitmaps.count > 0) {
            let imageBitmap = imageBitmaps[pageIndex]
            // get the real imagesize in pixels
            // look at <http://briksoftware.com/blog/?p=72>
            let imageSize = NSMakeSize(CGFloat(imageBitmap.pixelsWide), CGFloat(imageBitmap.pixelsHigh))
            var imageFrame = NSZeroRect
            imageFrame.size = fitImageIntoMainFrameRespectingAspectRatio(imageSize)
            if (inFullScreen) {
                imageFrame.origin = viewFrameOrigin
            }
            else {
                view.window!.setFrameOrigin(viewFrameOrigin)
                view.window!.setContentSize((viewFrameSize))
            }
            let image = NSImage()
            image.addRepresentation(imageBitmap)
            imageSubview.frame = imageFrame
            imageSubview.imageScaling = NSImageScaling.scaleProportionallyUpOrDown
            imageSubview.image = image
            view.addSubview(imageSubview!)
            return true
        }
        return false
    }

    // following are the actions for menu entries
    @IBAction func openDocument(_ sender: NSMenuItem) {
        // open new file(s)
//        entryIndex = -1
        urlIndex = -1
        processImages()
    }

    @IBAction func closeZIP(_ sender: NSMenuItem) {
        // return from zipped images
        sender.isEnabled = false
        entryIndex = -1
        imageURLs.remove(at: urlIndex)
        urlIndex -= 1
        zipIsOpen = false
        processImages()
    }

    @IBAction func sheetUp(_ sender: NSMenuItem) {
        // show page up
        if (!imageBitmaps.isEmpty) {
            let nextIndex = pageIndex - 1
            if (nextIndex >= 0) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }

    @IBAction func sheetDown(_ sender: NSMenuItem) {
        // show page down
        if (imageBitmaps.count > 1) {
            let nextIndex = pageIndex + 1
            if (nextIndex < imageBitmaps.count) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }

    @IBAction func previousImage(_ sender: NSMenuItem) {
        // show previous image
        if zipIsOpen {
            // display previous image of entry in zip archive
            let nextIndex = entryIndex - 1
            if (nextIndex >= 0) {
                entryIndex = nextIndex
                imageViewWithArchiveEntry()
            }
        }
        else {
            if (urlIndex >= 0) {
                // test what is in previuos URL
                let nextIndex = urlIndex - 1
                if (nextIndex >= 0) {
                    urlIndex = nextIndex
                    processImages()
                }
            }
        }
    }
    
    @IBAction func nextImage(_ sender: AnyObject) {
        // show next image
        if zipIsOpen {
            // display next image from zip entry
            let nextindex = entryIndex + 1
            if (nextindex < imageArchive?.entries.count) {
                entryIndex = nextindex
                imageViewWithArchiveEntry()
            }
        }
        else {
            if (urlIndex >= 0) {
                // test what is in next URL
                let nextIndex = urlIndex + 1
                if (nextIndex < imageURLs.count) {
                    urlIndex = nextIndex
                    processImages()
                }
            }
        }
    }

    @IBAction func slideShow(_ sender: NSMenuItem) {
        // start slide show, yes or no
        let item = sender
        if (showSlides) {
            item.state = NSOffState
            showSlides = false
            slidesTimer?.invalidate()
        }
        else {
            item.state = NSOnState
            showSlides = true
            slidesTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(nextImage(_:)), userInfo: nil, repeats: true)
        }
    }

// look at <https://www.brandpending.com/2016/02/21/opening-and-saving-custom-document-types-from-a-swift-cocoa-application/>
    // notification from AppDelegate
    func openData(_ notification: Notification) {
        // invoked when an item of recent documents is clicked
        if let fileURL = notification.object as? URL {
            urlIndex += 1
            imageURLs.insert(fileURL, at: urlIndex)
            processImages()
        }
    }

    // following are methods for window delegate
    func windowWillEnterFullScreen(_ notification: Notification) {
        // window will enter full screen mode
        if (imageSubview != nil) {
            imageSubview!.removeFromSuperviewWithoutNeedingDisplay()
        }
        inFullScreen = true
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        // in full screen the view must have its own origin, correct it
        if (imageSubview != nil) {
            imageSubview!.frame.origin = viewFrameOrigin
            view.addSubview(imageSubview!)
        }
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        // window will exit full screen mode
        if (imageSubview != nil) {
            imageSubview!.removeFromSuperviewWithoutNeedingDisplay()
        }
        inFullScreen = false
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        // window did exit full screen mode
        // correct wrong framesize, if during fullscreen mode
        // another image was loaded
        if (imageSubview != nil) {
            imageSubview!.setFrameOrigin(NSZeroPoint)
            view.window!.setFrameOrigin(viewFrameOrigin)
            view.window!.setContentSize((viewFrameSize))
            view.addSubview(imageSubview!)
        }
    }

}

