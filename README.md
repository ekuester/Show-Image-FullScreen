# Show-Image-FullScreen
Show images under OSX on full Screen

Show Images of different kind under OSX

Show the images in an NSImageView optionally on full screen ( relatively spartan but working )

The program was written first in Swift 2.2 and now changed to Swift 3 for Mac OS X.

The development environment is now is Xcode 8 under OS X 10.12 aka macOS Sierra.
The storyboard method ( main.storyboard ) is used for coupling AppDelegate, WindowsController and ViewController together. You will find some useful methods to exchange data between these three objects. I wrote this program to become familiar with the Swift language and to get a feeling how to display images on the screen. It contains a lot of useful stuff regarding handling of windows, menus, images.

Usage:
You can choose one or more image files (including EPS, multipage TIFFs and PDF documents) from a directory, which are displayed successively. The image is manipulated so that it fits best into the main Screen. 

The sequence of the shown images is controlled by the cursor keys:

- left : previous image

- right : next image

- up : previous page of document

- down : next page of document

There is a link in the source code to the ZipZap framework

- see <https://github.com/pixelglow/zipzap>

Thanks to this framework also images from a zipped archive can be shown, when you choose one. Cursor key control is in the manner as mentioned. The backspace key control gives you the possibility to return from displaying the zipped images and choose another sequence.

Further control is possible in the menu bar with help of the "View" menu. You can choose a built-in rudimentary slideshow function.

The program fills the recent documents entries under the "File" menu und you can use them in the normal manner.

Disclaimer: Use the program for what purpose you like, but hold in mind, that I will not be responsible for any harm it will cause to your hard- or software. It was your decision to use this piece of software.
