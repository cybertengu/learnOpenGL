package code

import "core:math/linalg"
import gl "vendor:OpenGL"
import "core:strconv"
import "core:strings"

MAX_BONE_INFLUENCE :: 4

Vertex :: struct {
	Position, Normal : linalg.Vector3f32,
	TexCoords : linalg.Vector2f32,
	Tangent, Bitangent : linalg.Vector3f32,
	mBoneIDs : [MAX_BONE_INFLUENCE]i32,
	mWeights : [MAX_BONE_INFLUENCE]f32,
}

Texture :: struct {
	id : u32,
	type, path : string,
}

Mesh :: struct {
	vertices : [dynamic]Vertex,
	indices : [dynamic]u32,
	textures : [dynamic]Texture,
	VAO, VBO, EBO : u32,
}

setMesh :: proc(vertices : [dynamic]Vertex, indices : [dynamic]u32, textures : [dynamic]Texture) -> Mesh
{
	result : Mesh
	result.vertices = vertices
	result.indices = indices
	result.textures = textures
	setupMesh(&result)
	return result
}

drawMesh :: proc(mesh : ^Mesh, shaderID : u32)
{
	diffuseNr : int = 1
	specularNr : int = 1
	normalNr : int = 1
	heightNr : int = 1
	buf : [4]u8
	for i : i32 = 0; i < i32(len(mesh.textures)); i += 1
	{
		gl.ActiveTexture(gl.TEXTURE0 + u32(i)) // activate proper texture unit before binding
		// retrieve texture number (the N in diffuse_textureN)
		number, name : string
		name = mesh.textures[i].type
		if name == "texture_diffuse"
		{
			diffuseNr += 1
			number = strconv.itoa(buf[:], diffuseNr)
		}
		else if name == "texture_specular"
		{
			specularNr += 1
			number = strconv.itoa(buf[:], specularNr)
		}
		else if name == "texture_normal"
		{
			normalNr += 1
			number = strconv.itoa(buf[:], normalNr)
		}
		else if name == "texture_height"
		{
			heightNr += 1
			number = strconv.itoa(buf[:], heightNr)
		}
		fullName := [?]string { "material.", name, number }
		concatenateFullName := strings.concatenate(fullName[:])
		setInt(strings.clone_to_cstring(concatenateFullName), i, shaderID)
	}

	// draw mesh
	gl.BindVertexArray(mesh.VAO)
	gl.DrawElements(gl.TRIANGLES, i32(len(mesh.indices)), gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)

	// always good practice to set everything back to defaults once configured.
	gl.ActiveTexture(gl.TEXTURE0)

}

setupMesh :: proc(mesh : ^Mesh)
{
	gl.GenVertexArrays(1, &mesh.VAO)
	gl.GenBuffers(1, &mesh.VBO)
	gl.GenBuffers(1, &mesh.EBO)

	gl.BindVertexArray(mesh.VAO)
	gl.BindBuffer(gl.ARRAY_BUFFER, mesh.VBO)

	gl.BufferData(gl.ARRAY_BUFFER, len(mesh.vertices) * size_of(Vertex), &mesh.vertices[0], gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(mesh.indices) * size_of(u32), &mesh.indices[0], gl.STATIC_DRAW)

	// vertex positions
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(0))
	// vertex normals
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, Normal)))
	// vertex texture coords
	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, TexCoords)))
	// vertex tangent
        gl.EnableVertexAttribArray(3)
        gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, Tangent)))
        // vertex bitangent
        gl.EnableVertexAttribArray(4)
        gl.VertexAttribPointer(4, 3, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, Bitangent)))
	// ids
	gl.EnableVertexAttribArray(5)
	gl.VertexAttribPointer(5, 4, gl.INT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, mBoneIDs)))

	// weights
	gl.EnableVertexAttribArray(6)
	gl.VertexAttribPointer(6, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), uintptr(offset_of(Vertex, mWeights)))
        //gl.BindVertexArray(0)
}

