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
	programID := setShader("texture.vs", "texture.fs")

	VBO, VAO, EBO : u32
	gl.GenVertexArrays(1, &VAO)
	gl.GenBuffers(1, &VBO)
	gl.GenBuffers(1, &EBO)

	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAO)

	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)

	// position attribute
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)  

	// texture coord attribute
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(3 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// load and create a texture 
	texture1, texture2 : u32
	gl.GenTextures(1, &texture1)
	gl.BindTexture(gl.TEXTURE_2D, texture1) // all upcoming GL_TEXTURE_2D operations now have effect on this texture object
	// set the texture wrapping parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)	// set texture wrapping to gl.REPEAT (default wrapping method)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	// set texture filtering parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	// load image, create texture and generate mipmaps
	width, height, nrChannels : i32
	// The FileSystem::getPath(...) is part of the GitHub repository so we can find files on any IDE/platform replace it with your own image path.
	stbi.set_flip_vertically_on_load(1)
	data := stbi.load("container.jpg", &width, &height, &nrChannels, 0)
	if data != nil
	{
		gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, data)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}
	else
	{
		fmt.eprintf("Failed to load texture")
	}
	stbi.image_free(data)

	gl.GenTextures(1, &texture2)
	gl.BindTexture(gl.TEXTURE_2D, texture2) // all upcoming GL_TEXTURE_2D operations now have effect on this texture object
	// set the texture wrapping parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)	// set texture wrapping to gl.REPEAT (default wrapping method)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	// set texture filtering parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	data2 := stbi.load("awesomeface.png", &width, &height, &nrChannels, 0)
	if data2 != nil
	{
		gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data2)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}
	else
	{
		fmt.eprintf("Failed to load texture.")
	}
	stbi.image_free(data2)

	// note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	// You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
	// VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
	gl.BindVertexArray(0)
	//gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	//gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	gl.UseProgram(programID)
	//gl.Uniform1i(gl.GetUniformLocation(programID, "texture1"), 0)
	setInt("texture1", 0, programID)
	setInt("texture2", 1, programID)

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

		// bind Texture
		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.ActiveTexture(gl.TEXTURE1)
		gl.BindTexture(gl.TEXTURE_2D, texture2)

		// activate shader
		gl.UseProgram(programID)
		setFloat("mixValue", mixValue, programID)	

		// note that we're translating the scene in the reverse direction of where we want to move
		projection := linalg.matrix4_perspective_f32(linalg.to_radians(camera.Zoom), SCREEN_WIDTH / SCREEN_HEIGHT, 0.1, 100)
		setMat4("projection", &projection, programID)
		
		// camera/view transformation
		view := getViewMatrix(&camera)
		setMat4("view", &view, programID)

		// render container
		gl.BindVertexArray(VAO)
		for i := 0; i < 10; i += 1
		{
			model := linalg.identity_matrix(linalg.Matrix4f32)
			model = linalg.matrix_mul(model, linalg.matrix4_translate_f32(cubePositions[i]))
			angle := linalg.to_radians(20.0 * f32(i))
			model = linalg.matrix_mul(model, linalg.matrix4_rotate_f32(angle, [3]f32{1, 0.3, 0.5}))
			setMat4("model", &model, programID)

			gl.DrawArrays(gl.TRIANGLES, 0, 36)
		}

		// check and call events and swap the buffers
		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &EBO)
	gl.DeleteProgram(programID)

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

