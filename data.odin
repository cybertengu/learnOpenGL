package code

vertices : []f32 = { 
0.5, 0.5, 0, 
0, -0.5, 0,
0, 0.5, 0
}

indices : []u32 = {
0, 5, 4,
}

vertices2 : []f32 = {
0, -0.5, 0,
0, 0.5, 0,
-0.5, 0.5, 0
}

indices2 : []u32 = {
0, 1, 2
}

vertexShaderSource : cstring = "#version 460 core\n" +
"layout (location = 0) in vec3 aPos;\n" +
"void main()\n" +
"{\n" +
"gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);\n" +
"}"

fragmentShaderSource : cstring = "#version 460 core\n" +
"out vec4 FragColor;\n" +
"void main()\n" +
"{\n" +
"FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" +
"}"

fragmentShaderSource2 : cstring = "#version 460 core\n" +
"out vec4 FragColor;\n" +
"void main()\n" +
"{\n" +
"FragColor = vec4(0.93f, 0.91f, 0.62f, 1.0f);\n" +
"}"

