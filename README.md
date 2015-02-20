<p align="center" ><img src="https://raw.github.com/Bakuf/RTFramework/master/blade_rtframework.gif"></p>

# RT Framework

This is a framework I made for use with augmented reality, using OpenGLES 2.0. It was made to display content in 3d, for now there are only 4 types of contents :

 - Images (a standar plane with texture)
 - Sound (just a note image is displayed and the sound can be paused with a touch)
 - Video (a plane with animated texture)
 - 3d Model (md2 format)

I used vuforia cloud recognizion service when I was making the project, but it can be easily integrated in any other project just sending the model and projection matrix to the RTRender View Controller via NotificationCenter.

If there is no target you can rotate and zoom in and out the object, also you can mix any object together.

Enjoy =)

Author
----
Rodrigo Gálvez

Version
----

1.1
----

- Fixed build problem with AVPlayerItemStatus
- [[NSBundle mainBundle]pathForResource:ofType:] returned nil so I changed for [[NSBundle mainBundle]pathForResource:ofType:inDirectory:] instead


1.0
----


License
----

MIT


**Free Software, Hell Yeah!**
