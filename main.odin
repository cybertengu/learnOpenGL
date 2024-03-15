package code

import glfw "vendor:glfw/bindings"
import glf "vendor:glfw"
import gl "vendor:openGL"
import "core:os"
import "core:fmt"
import "core:runtime"
import "core:strings"

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

	nrAttributes : i32
	gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &nrAttributes);
	fmt.printf("Maximum nr of vertex attributes supported: %d", nrAttributes)

	// build and compile our shader program
	// vertex shader
	vertexShader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertexShader, 1, &vertexShaderSource, nil)
	gl.CompileShader(vertexShader)
	// check for shader compile errors
	success : i32
	infoLog : [512]u8
	gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success)
	if success == 0
	{
		gl.GetShaderInfoLog(vertexShader, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR: Shader Vertex Compilation Failed\n%s", infoLog)
		os.exit(-3)
	}
	// fragment shader
	fragmentShader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShader, 1, &fragmentShaderSource, nil)
	gl.CompileShader(fragmentShader)
	// check for shader compile errors
	gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success)
	if success == 0
	{
		gl.GetShaderInfoLog(fragmentShader, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR: Shader Fragment Compilation Failed\n%s", infoLog)
		os.exit(-3)
	}
	// link shaders
	shaderProgram := gl.CreateProgram()
	gl.AttachShader(shaderProgram, vertexShader)
	gl.AttachShader(shaderProgram, fragmentShader)
	gl.LinkProgram(shaderProgram)
	// check for linking errors
	gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	if success == 0
	{
		gl.GetProgramInfoLog(shaderProgram, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR: Shader Program Linking Failed\n%s", infoLog)
		os.exit(-4)
	}
	gl.DeleteShader(fragmentShader)

	// fragment shader
	fragmentShaderYellow := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragmentShaderYellow, 1, &fragmentShaderSource2, nil)
	gl.CompileShader(fragmentShaderYellow)
	// check for shader compile errors
	gl.GetShaderiv(fragmentShaderYellow, gl.COMPILE_STATUS, &success)
	if success == 0
	{
		gl.GetShaderInfoLog(fragmentShaderYellow, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR: Shader Fragment Compilation Failed\n%s", infoLog)
		os.exit(-3)
	}
	shaderProgramYellow := gl.CreateProgram()
	gl.AttachShader(shaderProgramYellow, vertexShader)
	gl.AttachShader(shaderProgramYellow, fragmentShaderYellow)
	gl.LinkProgram(shaderProgramYellow)
	// check for linking errors
	gl.GetProgramiv(shaderProgramYellow, gl.LINK_STATUS, &success)
	if success == 0
	{
		gl.GetProgramInfoLog(shaderProgramYellow, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR: Shader Program Linking Failed\n%s", infoLog)
		os.exit(-4)
	}
	gl.DeleteShader(vertexShader)
	gl.DeleteShader(fragmentShaderYellow)

	VBOs, VAOs : [2]u32
	gl.GenVertexArrays(2, &VAOs[0])
	gl.GenBuffers(2, &VBOs[0])
	// bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
	gl.BindVertexArray(VAOs[0])

	gl.BindBuffer(gl.ARRAY_BUFFER, VBOs[0])
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices[0]) * len(vertices), raw_data(vertices), gl.STATIC_DRAW)

	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices[0]) * len(indices), raw_data(indices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)  

	gl.BindVertexArray(VAOs[1])
	gl.BindBuffer(gl.ARRAY_BUFFER, VBOs[1])
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices2[0]) * len(vertices2), raw_data(vertices2), gl.STATIC_DRAW)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, uintptr(0))
	gl.EnableVertexAttribArray(0)

	// note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	// You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
	// VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
	gl.BindVertexArray(0)
	//gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
	//gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	
	// render loop
	for !glfw.WindowShouldClose(window)
	{
		// input
		processInput(&window)
		
		// rendering commands
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// draw our first triangle
		gl.UseProgram(shaderProgram)
		
		gl.BindVertexArray(VAOs[0])
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		gl.UseProgram(shaderProgramYellow)
		gl.BindVertexArray(VAOs[1])
		gl.DrawArrays(gl.TRIANGLES, 0, 3)

		// check and call events and swap the buffers
		glfw.SwapBuffers(window)
		glfw.PollEvents()

	}

	// optional: de-allocate all resources once they've outlived their purpose:
	gl.DeleteVertexArrays(1, &VAOs[0]);
	gl.DeleteBuffers(2, &VBOs[0]);
	gl.DeleteProgram(shaderProgram);

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
}

framebufferSizeCallback :: proc "c" (window : glfw.WindowHandle, width, height : i32)
{
	gl.Viewport(0, 0, width, height)
}
