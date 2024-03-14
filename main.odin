package code

import glfw "vendor:glfw/bindings"
import glf "vendor:glfw"
import gl "vendor:openGL"
import "core:os"
import "core:fmt"
import "core:runtime"
import "core:strings"

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
}

framebufferSizeCallback :: proc "c" (window : glfw.WindowHandle, width, height : i32)
{
	gl.Viewport(0, 0, width, height)
}

main :: proc()
{
	if (!glfw.Init())
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

	VBO : u32
	gl.GenBuffers(1, &VBO)
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices[:]), gl.STATIC_DRAW)
	vertexShader : u32
	vertexShader = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertexShader, 1, &vertexShaderSource[0], nil)
	gl.CompileShader(vertexShader)

	success : i32
	infoLog : [^]u8
	gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success)

	if success != 0
	{
		gl.GetShaderInfoLog(vertexShader, 512, nil, infoLog)
		fmt.eprintf("ERROR: Shader Vertex Compilation Failed\n%s", infoLog)
		os.exit(-3)
	}

	fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShader, 1, &fragmentShaderSource[0], nil)
	gl.CompileShader(fragmentShader)

	shaderProgram := gl.CreateProgram()
	gl.AttachShader(shaderProgram, vertexShader)
	gl.AttachShader(shaderProgram, fragmentShader)
	gl.LinkProgram(shaderProgram)

	gl.GetShaderiv(shaderProgram, gl.LINK_STATUS, &success)
	if success != 0
	{
		gl.GetProgramInfoLog(shaderProgram, 512, nil, infoLog)
		fmt.eprintf("ERROR: Shader Program Linking Failed\n%s", infoLog)
		os.exit(-4)
	}

	gl.UseProgram(shaderProgram)

	gl.DeleteShader(vertexShader)
	gl.DeleteShader(fragmentShader)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)

	// 0. copy our vertices array in a buffer for OpenGL to use
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)
	// 1. then set the vertex attributes pointers
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)  
	// 2. use our shader program when we want to render an object
	gl.UseProgram(shaderProgram)
	// 3. now draw the object 
	//someOpenGLFunctionThatDrawsOurTriangle()
	VAO : u32
	gl.GenVertexArrays(1, &VAO)
	// ..:: Initialization code (done once (unless your object frequently changes)) :: ..
	// 1. bind Vertex Array Object
	gl.BindVertexArray(VAO)
	// 2. copy our vertices array in a buffer for OpenGL to use
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)
	// 3. then set our vertex attributes pointers
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)  

	for !glfw.WindowShouldClose(window)
	{
		// input
		processInput(&window)
		
		// rendering commands
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// draw the object
		gl.UseProgram(shaderProgram)
		gl.BindVertexArray(VAO)
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		// check and call events and swap the buffers
		glfw.SwapBuffers(window)
		glfw.PollEvents()

	}

	glfw.Terminate()
}

