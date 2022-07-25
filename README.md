# MAFocusNode
Custom Focus Node designed for SceneKit, a part of ARKit. Requires at least iOS 13.

Focus node reacts to changes in **camera angle and angular velocity** with room for additional customizability using focus node velocity.

The implementation rotates the focus node depending on the orientation of the camera. For example, if the camera is rotated 45 degrees counterclockwise along the z-axis, the focus node will also do the same.

![Screen Shot 2022-06-22 at 1 33 18 AM](https://user-images.githubusercontent.com/1800538/180707471-8241c50d-6b31-41d4-84c9-64acc3a39a6e.png)

Additionally, scale and rotation transforms area also applied onto the focus node depending on how the camera's angular velocity changes along the x and y axes.

![Screen Shot 2022-06-22 at 1 34 19 AM](https://user-images.githubusercontent.com/1800538/180707563-010bf44e-00ac-402c-b69d-78244885b2bb.png)

**Focus Node Demo:**

https://user-images.githubusercontent.com/1800538/180707744-b6603cb8-2580-426c-8490-68a4951c8ed0.mov

