package code

import ai "odin-assimp"
import "core:strings"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "core:math/linalg"
import stbi "vendor:stb/image"
import gl "vendor:OpenGL"
import "base:intrinsics"

Model :: struct {
	textures_loaded : [dynamic]Texture,
	meshes : [dynamic]Mesh,
	directory : string,
	gammaCorrection : bool,
}

drawModel :: proc(model : ^Model, shaderID : u32)
{
	for i : u32 = 0; i < u32(len(model.meshes)); i += 1
	{
		drawMesh(&model.meshes[i], shaderID)
	}
}

loadModel :: proc(model : ^Model, path : string)
{
	scene := ai.import_file_from_file(path, u32(ai.PostProcessSteps.Triangulate | ai.PostProcessSteps.FlipUVs))
	if scene == nil || (u32(scene.mFlags) & u32(ai.SceneFlags.INCOMPLETE)) > 0 || scene.mRootNode == nil
	{
		fmt.eprintf("ERROR::ASSIMP::Load Model::%s", ai.get_error_string())
		return
	}
	model.directory = os.get_current_directory()
	pathWithoutFilename := path[:strings.last_index(path, "\\")]
	fullName := [?]string { model.directory, "\\", pathWithoutFilename }
	filename := strings.concatenate(fullName[:])
	model.directory = filename

	processNode(model, scene.mRootNode, scene)
}

processNode :: proc(model : ^Model, node : ^ai.Node, scene : ^ai.Scene)
{
    // process all the node's meshes (if any)
    for i : u32 = 0; i < u32(node.mNumMeshes); i += 1
    {
	mesh := scene.mMeshes[node.mMeshes[i]]
        append(&model.meshes, processMesh(model, mesh, scene))
    }
    // then do the same for each of its children
    for i : u32 = 0; i < node.mNumChildren; i += 1
    {
        processNode(model, node.mChildren[i], scene)
    }
}

processMesh :: proc(model : ^Model, mesh : ^ai.Mesh, scene : ^ai.Scene) -> Mesh
{
	// data to fill
	vertices : [dynamic]Vertex
        indices : [dynamic]u32
        textures : [dynamic]Texture

        // walk through each of the mesh's vertices
        for i : u32 = 0; i < u32(mesh.mNumVertices); i += 1
        {
		vertex : Vertex
            vector : linalg.Vector3f32 // we declare a placeholder vector since assimp uses its own vector class that doesn't directly convert to glm's vec3 class so we transfer the data to this placeholder glm::vec3 first.
            // positions
            vector.x = mesh.mVertices[i].x
            vector.y = mesh.mVertices[i].y
            vector.z = mesh.mVertices[i].z
            vertex.Position = vector
            // normals
            if mesh.mNormals != nil
            {
                vector.x = mesh.mNormals[i].x
                vector.y = mesh.mNormals[i].y
                vector.z = mesh.mNormals[i].z
                vertex.Normal = vector
            }
            // texture coordinates
            if mesh.mTextureCoords[0] != nil // does the mesh contain texture coordinates?
            {
		    vec : linalg.Vector2f32
                // a vertex can contain up to 8 different texture coordinates. We thus make the assumption that we won't 
                // use models where a vertex can have multiple texture coordinates so we always take the first set (0).
                vec.x = mesh.mTextureCoords[0][i].x
                vec.y = mesh.mTextureCoords[0][i].y
                vertex.TexCoords = vec
                // tangent
		if mesh.mTangents != nil
		{
			vector.x = mesh.mTangents[i].x
			vector.y = mesh.mTangents[i].y
			vector.z = mesh.mTangents[i].z
			vertex.Tangent = vector
		}
                // bitangent
		if mesh.mBitangents != nil
		{
			vector.x = mesh.mBitangents[i].x
			vector.y = mesh.mBitangents[i].y
			vector.z = mesh.mBitangents[i].z
			vertex.Bitangent = vector
		}
            }
            else
	    {
                vertex.TexCoords = linalg.Vector2f32{0.0, 0.0}
		}

            append(&vertices, vertex)
        }
        // now wak through each of the mesh's faces (a face is a mesh its triangle) and retrieve the corresponding vertex indices.
        for i : u32 = 0; i < mesh.mNumFaces; i += 1
        {
		face := mesh.mFaces[i]
            // retrieve all indices of the face and store them in the indices vector
            for j : u32 = 0; j < face.mNumIndices; j += 1
	    {
                append(&indices, face.mIndices[j])        
		}
        }
        // process materials
	material := scene.mMaterials[mesh.mMaterialIndex]    
        // we assume a convention for sampler names in the shaders. Each diffuse texture should be named
        // as 'texture_diffuseN' where N is a sequential number ranging from 1 to MAX_SAMPLER_NUMBER. 
        // Same applies to other texture as the following list summarizes:
        // diffuse: texture_diffuseN
        // specular: texture_specularN
        // normal: texture_normalN

        // 1. diffuse maps
        diffuseMaps := loadMaterialTextures(model, material, ai.TextureType.DIFFUSE, "texture_diffuse")
	append(&textures, ..diffuseMaps[:])
        // 2. specular maps
        specularMaps := loadMaterialTextures(model, material, ai.TextureType.SPECULAR, "texture_specular")
	append(&textures, ..specularMaps[:])
        // 3. normal maps
        normalMaps := loadMaterialTextures(model, material, ai.TextureType.HEIGHT, "texture_normal")
	append(&textures, ..normalMaps[:])
        // 4. height maps
        heightMaps := loadMaterialTextures(model, material, ai.TextureType.AMBIENT, "texture_height")
	append(&textures, ..heightMaps[:])
        
        // return a mesh object created from the extracted mesh data
	result : Mesh
	result.vertices = vertices
	result.indices = indices
	result.textures = textures
	setupMesh(&result)
        return result
    }

    // checks all material textures of a given type and loads the textures if they're not loaded yet.
    // the required info is returned as a Texture struct.
    loadMaterialTextures :: proc(model : ^Model, mat : ^ai.Material, type : ai.TextureType, typeName : string) -> [dynamic]Texture
    {
        textures : [dynamic]Texture
        for i : u32 = 0; i < u32(ai.get_material_textureCount(mat, type)); i += 1
        {
		str : ai.String
            ai.get_material_texture(mat, type, i, &str, nil, nil, nil, nil, nil)
            // check if texture was loaded before and if so, continue to next iteration: skip loading a new texture
            skip := false
            for j : u32 = 0; j < u32(len(model.textures_loaded)); j += 1
            {
                if model.textures_loaded[j].path == transmute(string)str.data[:]
                {
                    append(&textures, model.textures_loaded[j])
                    skip = true // a texture with the same filepath has already been loaded, continue to next one. (optimization)
                    break
                }
            }
            if(!skip)
            {   // if texture hasn't been loaded already, load it
	    texture : Texture
                texture.id = TextureFromFile(transmute(string)str.data[:], model.directory, true)
                texture.type = typeName
                texture.path = transmute(string)str.data[:]
                append(&textures, texture)
                append(&model.textures_loaded, texture)  // store it as texture loaded for entire model, to ensure we won't unnecessary load duplicate textures.
            }
        }
        return textures
    }

    TextureFromFile :: proc(path : string, directory : string, gamma : bool) -> u32
{
	filename := string(path)
	fullName := [?]string { directory, "/", filename }
	filename = strings.concatenate(fullName[:])

    textureID : u32
    gl.GenTextures(1, &textureID)

    width, height, nrComponents : i32
    data := stbi.load(strings.clone_to_cstring(filename), &width, &height, &nrComponents, 0)
    if data != nil
    {
	    format : gl.GL_Enum
        if (nrComponents == 1)
	{
            format = gl.GL_Enum.RED
    }
        else if (nrComponents == 3)
	{
            format = gl.GL_Enum.RGB
    }
        else if (nrComponents == 4)
	{
           format = gl.GL_Enum.RGBA
   }

        gl.BindTexture(gl.TEXTURE_2D, textureID)
        gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), width, height, 0, u32(format), gl.UNSIGNED_BYTE, data)
        gl.GenerateMipmap(gl.TEXTURE_2D)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

        stbi.image_free(data)
    }
    else
    {
        fmt.eprint("Texture failed to load at path: ", path)
        stbi.image_free(data)
    }

    return textureID
}

