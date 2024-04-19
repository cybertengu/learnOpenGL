package code

import "core:math"
import "core:math/linalg"

CameraMovement :: enum
{
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT,
}

YAW : f32 = -90
PITCH : f32 = 0
SPEED : f32 = 2.5
SENSITIVITY : f32 = 0.1
ZOOM : f32 = 45

Camera :: struct
{
	Position, Front, Up, Right, WorldUp : linalg.Vector3f32,
	Yaw, Pitch, MovementSpeed, MouseSensitivity, Zoom : f32,
}

setCamera :: proc(camera : ^Camera, position := linalg.Vector3f32{0, 0, 0}, up := linalg.Vector3f32{0, 1, 0}, yaw := YAW, pitch := PITCH)
{
	camera.Position = position
	camera.WorldUp = up
	camera.Yaw = yaw
	camera.Pitch = pitch
	updateCameraVectors(camera)
	camera.MovementSpeed = SPEED
	camera.MouseSensitivity = SENSITIVITY
	camera.Zoom = ZOOM
}

setCameraPosition :: proc(camera : ^Camera, posX, posY, posZ, upX, upY, upZ, yaw, pitch : f32)
{
	setCamera(camera, linalg.Vector3f32{posX, posY, posZ}, linalg.Vector3f32{upX, upY, upZ}, yaw, pitch)
}

getViewMatrix :: proc(camera : ^Camera) -> linalg.Matrix4f32
{
	return linalg.matrix4_look_at_f32(camera.Position, camera.Position + camera.Front, camera.Up)
}

processKeyboard :: proc(camera : ^Camera, direction : CameraMovement, deltaTime : f32)
{
	velocity : f32 = camera.MovementSpeed * deltaTime
	if direction == .FORWARD
	{
		camera.Position += camera.Front * velocity
	}
	if direction == .BACKWARD
	{
		camera.Position -= camera.Front * velocity
	}
	if direction == .LEFT
	{
		camera.Position -= camera.Right * velocity
	}
	if direction == .RIGHT
	{
		camera.Position += camera.Right * velocity
	}
}

processMouseMovement :: proc(camera : ^Camera, x, y : f32, constrainPitch : bool = true)
{
	xoffset := x * camera.MouseSensitivity
	yoffset := y * camera.MouseSensitivity

	camera.Yaw += xoffset
	camera.Pitch += yoffset

	if constrainPitch
	{
		if camera.Pitch > 89
		{
			camera.Pitch = 89
		}
		if camera.Pitch < -89
		{
			camera.Pitch = -89
		}
	}

	updateCameraVectors(camera)
}

processMouseScroll :: proc(camera : ^Camera, yoffset : f32)
{
	camera.Zoom -= yoffset
	if camera.Zoom < 1
	{
		camera.Zoom = 1
	}
	if camera.Zoom > 45
	{
		camera.Zoom = 45
	}
}

updateCameraVectors :: proc(camera : ^Camera)
{
	front : linalg.Vector3f32
	front.x = math.cos_f32(linalg.to_radians(camera.Yaw)) * math.cos_f32(linalg.to_radians(camera.Pitch))
	front.y = math.sin_f32(linalg.to_radians(camera.Pitch))
	front.z = math.sin_f32(linalg.to_radians(camera.Yaw)) * math.cos_f32(linalg.to_radians(camera.Pitch))
	camera.Front = linalg.vector_normalize(front)
	camera.Right = linalg.vector_normalize(linalg.vector_cross(camera.Front, camera.WorldUp))
	camera.Up = linalg.vector_normalize(linalg.vector_cross(camera.Right, camera.Front))
}

