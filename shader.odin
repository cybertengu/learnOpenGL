package code

import gl "vendor:openGL"
import "core:os"
import "core:fmt"
import "core:strings"

Shader :: struct
{
	ID : u32,
}

setBool :: proc(name : cstring, value : bool, ID : u32)
{	
	result : i32
	if value
	{
		result = 1
	}
	gl.Uniform1i(gl.GetUniformLocation(ID, name), result)
}

setInt :: proc(name : cstring, value : i32, ID : u32)
{
	gl.Uniform1i(gl.GetUniformLocation(ID, name), value)
}

setFloat :: proc(name : cstring, value : f32, ID : u32)
{
	gl.Uniform1f(gl.GetUniformLocation(ID, name), value)
}

setShader :: proc(vertexPath, fragmentPath : string) -> u32
{
	// 1. retrieve the vertex/fragment source code from filePath
	vertexCode, fragmentCode : string
	vShaderFile, successFile := os.read_entire_file_from_filename(vertexPath)
	if successFile != true
	{
		fmt.eprintf("ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ for Vertex file: %s", vertexPath)
		os.exit(-5)
	}

	fShaderFile, shaderSuccess := os.read_entire_file_from_filename(fragmentPath)
	if shaderSuccess != true
	{
		fmt.eprintf("ERROR::SHADER::FILE_NOT_SUCCESSFULLY_READ for Fragment file: %s", fragmentPath)
		os.exit(-6)
	}

	vShaderCode := strings.clone_to_cstring(string(vShaderFile))
	fShaderCode := strings.clone_to_cstring(string(fShaderFile))

	// 2. compile the shaders
	vertex, fragment : u32
	success : i32
	infoLog : [512]u8

	// vertex shader
	vertex = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex, 1, &vShaderCode, nil)
	gl.CompileShader(vertex)
	// print compile errors if any
	gl.GetShaderiv(vertex, gl.COMPILE_STATUS, &success)
	if success == 0
	{
		gl.GetShaderInfoLog(vertex, 512, nil, &infoLog[0])
		fmt.eprint("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n%s", infoLog)
	}

	// similiar for Fragment Shader
	fragment = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment, 1, &fShaderCode, nil)
	gl.CompileShader(fragment)
	// print compile errors if any
	gl.GetShaderiv(fragment, gl.COMPILE_STATUS, &success)
	if success == 0
	{
		gl.GetShaderInfoLog(fragment, 512, nil, &infoLog[0])
		fmt.eprint("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n%s", infoLog)
	}

	// shader Program
	ID := gl.CreateProgram()
	gl.AttachShader(ID, vertex)
	gl.AttachShader(ID, fragment)
	gl.LinkProgram(ID)
	// print linking errors if any
	gl.GetProgramiv(ID, gl.LINK_STATUS, &success)
	if success == 0
	{
		gl.GetProgramInfoLog(ID, 512, nil, &infoLog[0])
		fmt.eprintf("ERROR::SHADER::PROGRAM::LINKING_FAILED\n%s", infoLog)
	}

	// delete the shaders as they're linked into our program now and no longer necessary
	gl.DeleteShader(vertex)
	gl.DeleteShader(fragment)

	return ID
}

