package code

import glfw "vendor:glfw/bindings"
import glf "vendor:glfw"
import gl "vendor:openGL"
import stbi "vendor:stb/image"
import "core:os"
import "core:fmt"
import "core:runtime"
import "core:strings"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/linalg"

deltaTime, lastFrame : f64
lastX : f32 = 400
lastY : f32 = 300
firstMouse : bool = true
camera : Camera
lightPos := linalg.Vector3f32{1.2, 1.0, 2.0}

main :: proc()
{
	camera.Position = linalg.Vector3f32{0, 0, 3}
	setCamera(&camera, camera.Position)

	if !glfw.Init()
	{
	    // Initialization failed
	    fmt.eprintf("Could not initialize GLFW.")
	    os.exit(-1)

	}
	glfw.SetErrorCallback(errorCallback)
	glfw.WindowHint(glf.CONTEXT_VERSION_MAJOR, MAJOR_VERSION)
	glfw.WindowHint(glf.CONTEXT_VERSION_MINOR, MINOR_VERSION)
	glfw.WindowHint(glf.OPENGL_PROFILE, glf.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "OpenGL Learn", nil, nil)
	if window == nil
	{
	    // Window or OpenGL context creation failed
	    fmt.eprintf("Window or OpenGL context creation failed.")
	    os.exit(-2)
	}

	glfw.MakeContextCurrent(window)
	glfw.SetFramebufferSizeCallback(window, framebufferSizeCallback)
	gl.load_up_to(int(MAJOR_VERSION), MINOR_VERSION, glf.gl_set_proc_address)
	glfw.SetInputMode(window, glf.CURSOR, glf.CURSOR_DISABLED)
	glf.SetCursorPosCallback(window, glf.CursorPosProc(mouseCallback))
	glf.SetScrollCallback(window, glf.CursorPosProc(scrollCallback))

	nrAttributes : i32
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &nrAttributes)
	fmt.printf("Maximum nr of vertex attributes supported: %d\n", nrAttributes)

	// configure global opengl state
	gl.Enable(gl.DEPTH_TEST)

	// build and compile our shader program
	lightingID := setShader("materials.vs", "materials.fs")
	lightingCubeID := setShader("lightTexture.vs", "lightTexture.fs")

	VBO, cubeVAO : u32
	gl.GenVertexArrays(1, &cubeVAO)
	gl.GenBuffers(1, &VBO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(cubeVAO)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)  
	// normal attribute
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	lightCubeVAO : u32
	gl.GenVertexArrays(1, &lightCubeVAO)
	gl.BindVertexArray(lightCubeVAO)

	// we only need to bind to the VBO, the container's  VBO's data already contains the data.
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)

	// set the vertex attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	// render loop
	for !glfw.WindowShouldClose(window)
	{
		currentFrame := glfw.GetTime()
		deltaTime = currentFrame - lastFrame
		lastFrame = currentFrame

		// input
		processInput(&window)
		
		// rendering commands
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// change the light's position values over time.
		//lightPos.x = 1.0 + math.cos_f32(f32(glfw.GetTime())) * 2.0
		//lightPos.y = math.cos_f32(f32(glfw.GetTime()) / 2.0) * 1.0

		// activate shader
		gl.UseProgram(lightingID)
		setVec3("light.position", &lightPos, lightingID)
		setVec3("viewPos", &camera.Position, lightingID)

		// light properties
		lightColor : linalg.Vector3f32
		lightColor.x = math.sin_f32(f32(glfw.GetTime()) * 2.0)
		lightColor.y = math.sin_f32(f32(glfw.GetTime()) * 0.7)
		lightColor.z = math.sin_f32(f32(glfw.GetTime()) * 1.3)
		diffuseColor := linalg.Vector3f32{1.0, 1.0, 1.0}
		ambientColor := linalg.Vector3f32{1.0, 1.0, 1.0}
		setVec3("light.ambient", &ambientColor, lightingID)
		setVec3("light.diffuse", &diffuseColor, lightingID)
		setVec3xyz("light.specular", 1.0, 1.0, 1.0, lightingID)


		// material properities
		setVec3xyz("material.ambient", 0.0, 0.1, 0.06, lightingID)
		setVec3xyz("material.diffuse", 0.0, 0.50980392, 0.50980392, lightingID)
		setVec3xyz("material.specular", 0.50196078, 0.50196078, 0.50196078, lightingID)
		setFloat("material.shininess", 0.25, lightingID)

		// view/projection transformations
		projection := linalg.matrix4_perspective_f32(linalg.to_radians(camera.Zoom), SCREEN_WIDTH / SCREEN_HEIGHT, 0.1, 100)

		// camera/view transformation
		view := getViewMatrix(&camera)
		setMat4("projection", &projection, lightingID)
		setMat4("view", &view, lightingID)
		
		// world transformation
		model := linalg.identity_matrix(linalg.Matrix4f32)
		setMat4("model", &model, lightingID)

		// render the cube
		gl.BindVertexArray(cubeVAO)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// also draw the lamp object
		gl.UseProgram(lightingCubeID)
		setMat4("projection", &projection, lightingCubeID)
		setMat4("view", &view, lightingCubeID)
		model = linalg.identity_matrix(linalg.Matrix4f32)
		model = linalg.matrix_mul(model, linalg.matrix4_translate_f32(lightPos))
		model = linalg.matrix_mul(model, linalg.matrix4_scale_f32(linalg.Vector3f32{0.2, 0.2, 0.2}))
		setMat4("model", &model, lightingCubeID)
		setVec3("light", &lightColor, lightingCubeID)

		gl.BindVertexArray(lightCubeVAO)
		gl.DrawArrays(gl.TRIANGLES, 0, 36)

		// check and call events and swap the buffers
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &cubeVAO)
	gl.DeleteBuffers(1, &lightCubeVAO)
	gl.DeleteProgram(lightingID)
	gl.DeleteProgram(lightingCubeID)

	// glfw: terminate, clearing all previously allocated GLFW resources.
	glfw.Terminate()
}

errorCallback :: proc "c" (error: i32, description : cstring)
{
	context = runtime.default_context()
	fmt.eprintf("Error: %s\n", description)
}

processInput :: proc(window : ^glfw.WindowHandle)
{
	if glfw.GetKey(window^, glf.KEY_ESCAPE) == glf.PRESS
	{
		glfw.SetWindowShouldClose(window^, true)
	}
	
	if glfw.GetKey(window^, glf.KEY_W) == glf.PRESS
	{	
		processKeyboard(&camera, .FORWARD, f32(deltaTime))
	}
	if glfw.GetKey(window^, glf.KEY_S) == glf.PRESS
	{
		processKeyboard(&camera, .BACKWARD, f32(deltaTime))
	}
	if glfw.GetKey(window^, glf.KEY_A) == glf.PRESS
	{
		processKeyboard(&camera, .LEFT, f32(deltaTime))
	}
	if glfw.GetKey(window^, glf.KEY_D) == glf.PRESS
	{
		processKeyboard(&camera, .RIGHT, f32(deltaTime))
	}
}

mouseCallback :: proc "c" (window : ^glfw.WindowHandle, xposIn, yposIn : f64)
{
	context = runtime.default_context()

	xpos : f32 = f32(xposIn)
	ypos : f32 = f32(yposIn)

	if firstMouse
	{
		lastX = f32(xpos)
		lastY = f32(ypos)
		firstMouse = false
	}

	xoffset : f32 = xpos - lastX
	yoffset : f32 = lastY - ypos

	lastX = xpos
	lastY = ypos

	processMouseMovement(&camera, xoffset, yoffset)
}

scrollCallback :: proc "c" (window : ^glfw.WindowHandle, xoffset, yoffset : f64)
{
	context = runtime.default_context()
	processMouseScroll(&camera, f32(yoffset))
}

framebufferSizeCallback :: proc "c" (window : glfw.WindowHandle, width, height : i32)
{
	gl.Viewport(0, 0, width, height)
}

