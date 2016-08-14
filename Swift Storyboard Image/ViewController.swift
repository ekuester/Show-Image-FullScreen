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
import ZipZap

class ViewController: NSViewController, NSWindowDelegate {

    var defaultSession: NSURLSession!

    var closeZIPItem: NSMenuItem!
    var entryIndex: Int = -1
    var pageIndex: Int = 0
    var previousUrlIndex = -1
    var urlIndex: Int = -1

    var imageBitmaps = [NSImageRep]()
    var imageTitle = String()
    var imageArchive: ZZArchive? = nil
    var imageURLs = [NSURL]()

    var directoryURL: NSURL = NSURL()
    var inFullScreen: Bool = false
    var mainFrame: NSRect!
    var sharedDocumentController: NSDocumentController!
    var slidesTimer: NSTimer? = nil
    var showSlides = false
    var viewFrameOrigin: NSPoint = NSZeroPoint
    var viewFrameSize: NSSize = NSZeroSize
    var workDirectoryURL: NSURL = NSURL()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.wantsLayer = true
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        self.defaultSession = NSURLSession(configuration: config)
        mainFrame = NSScreen.mainScreen()?.frame
        // find menu item "Close ZIP"
        let fileMenu = NSApp.mainMenu!.itemWithTitle("File")
        let fileMenuItems = fileMenu?.submenu?.itemArray
        for item in fileMenuItems! {
            if (item.title == "Close ZIP") {
                closeZIPItem = item
            }
        }
        let presentationOptions: NSApplicationPresentationOptions = [.HideDock, .AutoHideMenuBar]
        NSApp.presentationOptions = NSApplicationPresentationOptions(rawValue: presentationOptions.rawValue)
        sharedDocumentController = NSDocumentController.sharedDocumentController()
        // notification if file from recent document should be opened
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.openData(_:)), name: "com.image.openfile", object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.layer?.backgroundColor = NSColor.blackColor().CGColor
        // now window exists
        view.window!.delegate = self
        processImages()
    }

    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
            Swift.print("inside didSet of representedObject")
        }
    }

    func openImageDialog() -> [NSURL] {
        // generate File Open Dialog class
        let openDlg:NSOpenPanel = NSOpenPanel()
        openDlg.title = NSLocalizedString("Select image file", comment: "title of openPanel")
        let imageFile = ""
        openDlg.nameFieldStringValue = imageFile
        openDlg.directoryURL = workDirectoryURL
        openDlg.allowedFileTypes = ["bmp","jpg","jpeg","png","tif","tiff", "zip"]
        openDlg.allowsMultipleSelection = true;
        openDlg.canChooseDirectories = true;
        openDlg.canCreateDirectories = false;
        openDlg.canChooseFiles = true;
        if (openDlg.runModal() == NSFileHandlingPanelOKButton) {
            // OK
            workDirectoryURL = (openDlg.URL?.URLByDeletingLastPathComponent)!
            return openDlg.URLs
        }
        Swift.print("Cancel Button pressed")
        return [NSURL]()
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
            imageDialog.canChooseDirectories = true;
            imageDialog.canCreateDirectories = false;
            imageDialog.canChooseFiles = true;
            imageDialog.beginSheetModalForWindow(view.window!, completionHandler: { response in
                if response == NSFileHandlingPanelOKButton {
                    // NSFileHandlingPanelOKButton is Int(1)
                    self.urlIndex = 0
                    self.workDirectoryURL = (imageDialog.URL?.URLByDeletingLastPathComponent)!
                    self.imageURLs = imageDialog.URLs
                    self.processImages()
                }
            })
        }
        if (urlIndex >= 0) {
            // process images from existing URL(s)
            let actualURL = imageURLs[urlIndex]
            sharedDocumentController.noteNewRecentDocumentURL(actualURL)
            if let fileType = actualURL.pathExtension {
                switch fileType {
                case "zip":
                    // valid URL decodes zip file
                    do {
                        entryIndex = 0
                        imageArchive = try ZZArchive(URL: actualURL)
                        closeZIPItem.enabled = true
                        imageViewWithArchiveEntry()
                    } catch let error as NSError {
                        entryIndex = -1
                        Swift.print("ZipZap error: could not open archive in \(error.domain)")
                    }
                default:
                    previousUrlIndex = urlIndex
                    imageViewfromURLRequest(actualURL)
                }
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
    func fitImageIntoMainFrameRespectingAspectRatio(bitmap: NSImageRep) -> NSSize {
        var frameOrigin = NSZeroPoint
        var frameSize = mainFrame.size
        // calculate aspect ratios
        // get the real imagesize in pixels
        // look at <http://briksoftware.com/blog/?p=72>
        let imageSize = NSMakeSize(CGFloat(bitmap.pixelsWide), CGFloat(bitmap.pixelsHigh))
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

    func imageViewfromURLRequest(url: NSURL) {
        let urlRequest: NSURLRequest = NSURLRequest(URL: url)
        let task = defaultSession.dataTaskWithRequest(urlRequest, completionHandler: {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            if error != nil {
                Swift.print("error from data task: \(error!.localizedDescription) in \(error!.domain)")
                return
            }
            else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.fillBitmapsWithData(data!)
                    if  self.imageViewWithBitmap() {
                        self.view.window!.setTitleWithRepresentedFilename(url.lastPathComponent!)
                    }
                }
            }
        })
        task.resume()
    }

    func drawPDFPageInImage(page: CGPDFPage) -> NSImageRep? {
        let pageRect = CGPDFPageGetBoxRect(page, .MediaBox)
        let image = NSImage(size: pageRect.size)
        image.lockFocus()
        let context = NSGraphicsContext.currentContext()?.CGContext
        CGContextSetFillColorWithColor(context, NSColor.whiteColor().CGColor)
        CGContextFillRect(context,pageRect)
        CGContextDrawPDFPage(context, page);
        image.unlockFocus()
        return image.representations.first
    }

    func fillBitmapsWithData(graphicsData: NSData) {
        // generate representation(s) for image
        if (imageBitmaps.count > 0) {
            imageBitmaps.removeAll(keepCapacity: false)
        }
        pageIndex = 0
        imageBitmaps = NSBitmapImageRep.imageRepsWithData(graphicsData)
        if (imageBitmaps.count == 0) {
            // no valid bitmaps, try EPS ( contains always only one page )
            if let imageRep = NSEPSImageRep(data: graphicsData) {
                let boundingBox = imageRep.boundingBox
                imageRep.pixelsWide = Int(boundingBox.width)
                imageRep.pixelsHigh = Int(boundingBox.height)
                let image = NSImage()
                image.addRepresentation(imageRep)
                imageBitmaps.append(image.representations.first!)
            }
            // at last try PDF
            else {
                let provider = CGDataProviderCreateWithCFData(graphicsData)
                if let document = CGPDFDocumentCreateWithProvider(provider) {
                    let count = CGPDFDocumentGetNumberOfPages(document)
                    // go through pages
                    for i in 1 ... count {
                        if let page = CGPDFDocumentGetPage(document, i) {
                            if let imageRep = drawPDFPageInImage(page) {
                                imageBitmaps.append(imageRep)
                            }
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
            var imageFrame = NSZeroRect
            imageFrame.size = fitImageIntoMainFrameRespectingAspectRatio(imageBitmap)
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
            imageSubview.imageScaling = NSImageScaling.ScaleProportionallyUpOrDown
            imageSubview.image = image
            view.addSubview(imageSubview!)
            return true
        }
        return false
    }

    // following are the actions for menu entries
    @IBAction func openDocument(sender: NSMenuItem) {
        // open new file(s)
        entryIndex = -1
        urlIndex = -1
        processImages()
    }

    @IBAction func closeZIP(sender: NSMenuItem) {
        // return from zipped images
        sender.enabled = false
        entryIndex = -1
        urlIndex = -1
        processImages()
    }

    @IBAction func leafUp(sender: NSMenuItem) {
        // show page up
        if (!imageBitmaps.isEmpty) {
            let nextIndex = pageIndex - 1
            if (nextIndex >= 0) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }

    @IBAction func leafDown(sender: NSMenuItem) {
        // show page down
        if (imageBitmaps.count > 1) {
            let nextIndex = pageIndex + 1
            if (nextIndex < imageBitmaps.count) {
                pageIndex = nextIndex
                imageViewWithBitmap()
            }
        }
    }

    @IBAction func previousImage(sender: NSMenuItem) {
        // show previous image
        if (entryIndex >= 0) {
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
    
    @IBAction func nextImage(sender: AnyObject) {
        // show next image
        if (entryIndex >= 0) {
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

    @IBAction func slideShow(sender: NSMenuItem) {
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
            slidesTimer = NSTimer.scheduledTimerWithTimeInterval(3, target: self, selector: #selector(nextImage(_:)), userInfo: nil, repeats: true)
        }
    }
// look at <https://www.brandpending.com/2016/02/21/opening-and-saving-custom-document-types-from-a-swift-cocoa-application/>
// notification from AppDelegate
    func openData(notification: NSNotification) {
        // invoked when an item of recent documents is clicked
        Swift.print("object: \(notification.object)")
        if let fileURL = notification.object as? NSURL {
            urlIndex += 1
            imageURLs.insert(fileURL, atIndex: urlIndex)
            processImages()
        }
    }

    // following are methods for window delegate
    func windowWillEnterFullScreen(notification: NSNotification) {
        // window will enter full screen mode
        if (subview != nil) {
            subview!.removeFromSuperviewWithoutNeedingDisplay()
        }
        inFullScreen = true
    }

    func windowDidEnterFullScreen(notification: NSNotification) {
        // in full screen the view must have its own origin, correct it
        if (subview != nil) {
            imageSubview!.frame.origin = viewFrameOrigin
            view.addSubview(subview!)
        }
    }

    func windowWillExitFullScreen(notification: NSNotification) {
        // window will exit full screen mode
        if (subview != nil) {
            subview!.removeFromSuperviewWithoutNeedingDisplay()
        }
        inFullScreen = false
    }

    func windowDidExitFullScreen(notification: NSNotification) {
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

