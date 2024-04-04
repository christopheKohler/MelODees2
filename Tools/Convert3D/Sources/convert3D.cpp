//
// Convert 3D file to Amiga Binary struct
//

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>

/* assimp include files. These three are usually needed. */
#include <assimp/cimport.h>
#include <assimp/scene.h>
#include <assimp/postprocess.h>

#include "ImageQuant.h"
#include "color.h"

#include "math/vector.h"
#include "math/quaternion.h"
#include "math/matrix.h"
using namespace mathing;

// Global variables
#define FINALCOLORS 8
color AllColors[FINALCOLORS]; // Real 8 colors

#define MAXBLENDCOLORS 512
colorblend AllColorBlend[MAXBLENDCOLORS];
int gColorBlendNumber = 0;

// Binary struct (Word, Long, Byte)
// Header:
// W : Nb Vertices (Max 256)
// W : Nb Normals (Max 256)
// W : Nb Quads (Max 256)
// W : Nb Triangles (Max 256)
// W : NB Colors (Max 256)
// Vertices: N*6bytes
// W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
// Normals: N*6bytes
// W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
// Quads: N*6bytes
// B B B B B B: Index1,2,3,4, color, Normal
// L End Marker : FFFFFFFF
// Triangles: N*6bytes
// B B B B : Index 1 2 3, Dummy, Color, Normal
// L End Marker : FFFFFFFF
// Base palette: 
// W : 8 colors ( 16 bytes)
// Color table: N colordithered
// For each color, 32 colorsdithered. Color 1, color 2, Dither id. = 16 bits (2 bytes)
// N*32*2 = N*64 bytes per color.

#ifdef _WIN32
#ifdef __cplusplus
extern "C" {
#endif
#include <windows.h>
#include <mmsystem.h>
#ifdef __cplusplus
}
#endif
#pragma comment(lib, "winmm.lib")
#else
#if defined(__unix__) || defined(__APPLE__)
#include <sys/time.h>
#else
#include <ctime>
#endif
#endif

// -- Fixed float
// Float 8:8
// 8:8 format is entire : fixed float.
// 00:00 is 0.0f
// 00:80 is 0.5f
// 00:C0 is 0.75f
// 01:00 is 1.0f
// FF:80 is - 0.5f
// FF:40 is - 0.75f
// FF:00 is - 1
class FixedFloat
{
public:
    FixedFloat();
    ~FixedFloat();
    FixedFloat(float value);
    void set(float value);
    void writetobufferas88(unsigned char* buff);
    void writetobufferasint(unsigned char* buff);
    void writetobufferaschar(unsigned char* buff);
public:
    float valuefloat;
};
FixedFloat::FixedFloat()
{
    valuefloat = 0.0f;
}
FixedFloat::~FixedFloat()
{

}
FixedFloat::FixedFloat(float _value)
{
    valuefloat = _value;
}
void FixedFloat::set(float _value)
{
    valuefloat = _value;
}
void FixedFloat::writetobufferas88(unsigned char* buff)
{
    int hexavalue;
    hexavalue = (int)((valuefloat) * 256.0f);
    buff[0] = (hexavalue >> 8);
    buff[1] = (hexavalue & 0x000000FF);
}
void FixedFloat::writetobufferasint(unsigned char* buff)
{
    int hexavalue;
    hexavalue = (int)valuefloat;
    buff[0] = (hexavalue >> 8);
    buff[1] = (hexavalue & 0x000000FF);
}
void FixedFloat::writetobufferaschar(unsigned char* buff)
{
    int hexavalue;
    hexavalue = (int)valuefloat;
    buff[0] = (hexavalue & 0x000000FF);
}

// Color function.
// Find best real color 
int FindBestRealColor(color colottofind)
{
    int bestcolor = 0;
    int smallesterror = 65000;
    for (int i = 0; i < FINALCOLORS; i++)
    {
        int error = AllColors[i].getdiff(colottofind);
        if (error < smallesterror)
        {
            smallesterror = error;
            bestcolor = i;
        }
    }
    return bestcolor;
}




class timerutil
{
public:
    typedef DWORD time_t;

    timerutil() { ::timeBeginPeriod(1); }
    ~timerutil() { ::timeEndPeriod(1); }

    void start() { t_[0] = ::timeGetTime(); }
    void end() { t_[1] = ::timeGetTime(); }

    time_t sec() { return (time_t)((t_[1] - t_[0]) / 1000); }
    time_t msec() { return (time_t)((t_[1] - t_[0])); }
    time_t usec() { return (time_t)((t_[1] - t_[0]) * 1000); }
    time_t current() { return ::timeGetTime(); }

private:
    DWORD t_[2];
};

/*
// ------------------------------------------------------------------------------------
static void PrintInfo(const tinyobj::attrib_t& attrib, const std::vector<tinyobj::shape_t>& shapes, const std::vector<tinyobj::material_t>& materials)
{
  std::cout << "# of vertices  : " << (attrib.vertices.size() / 3) << std::endl;
  std::cout << "# of normals   : " << (attrib.normals.size() / 3) << std::endl;
  std::cout << "# of texcoords : " << (attrib.texcoords.size() / 2)
    << std::endl;

  std::cout << "# of shapes    : " << shapes.size() << std::endl;
  std::cout << "# of materials : " << materials.size() << std::endl;

  for (size_t v = 0; v < attrib.vertices.size() / 3; v++) {
    printf("  v[%ld] = (%f, %f, %f)\n", static_cast<long>(v),
      static_cast<const double>(attrib.vertices[3 * v + 0]),
      static_cast<const double>(attrib.vertices[3 * v + 1]),
      static_cast<const double>(attrib.vertices[3 * v + 2]));
  }

  for (size_t v = 0; v < attrib.normals.size() / 3; v++) {
    printf("  n[%ld] = (%f, %f, %f)\n", static_cast<long>(v),
      static_cast<const double>(attrib.normals[3 * v + 0]),
      static_cast<const double>(attrib.normals[3 * v + 1]),
      static_cast<const double>(attrib.normals[3 * v + 2]));
  }

  for (size_t v = 0; v < attrib.texcoords.size() / 2; v++) {
    printf("  uv[%ld] = (%f, %f)\n", static_cast<long>(v),
      static_cast<const double>(attrib.texcoords[2 * v + 0]),
      static_cast<const double>(attrib.texcoords[2 * v + 1]));
  }

  // For each shape
  for (size_t i = 0; i < shapes.size(); i++) {
    printf("shape[%ld].name = %s\n", static_cast<long>(i),
      shapes[i].name.c_str());
    printf("Size of shape[%ld].indices: %lu\n", static_cast<long>(i),
      static_cast<unsigned long>(shapes[i].mesh.indices.size()));

    size_t index_offset = 0;

    assert(shapes[i].mesh.num_face_vertices.size() == shapes[i].mesh.material_ids.size());

    printf("shape[%ld].num_faces: %lu\n", static_cast<long>(i),static_cast<unsigned long>(shapes[i].mesh.num_face_vertices.size()));

    // For each face
    for (size_t f = 0; f < shapes[i].mesh.num_face_vertices.size(); f++)
    {
      size_t fnum = shapes[i].mesh.num_face_vertices[f];

      printf("  face[%ld].fnum = %ld\n", static_cast<long>(f),static_cast<unsigned long>(fnum));

      // For each vertex in the face
      for (size_t v = 0; v < fnum; v++)
      {
        tinyobj::index_t idx = shapes[i].mesh.indices[index_offset + v];
        printf("    face[%ld].v[%ld].idx = %d/%d/%d\n", static_cast<long>(f),static_cast<long>(v), idx.vertex_index, idx.normal_index,idx.texcoord_index);
      }

      printf("  face[%ld].material_id = %d\n", static_cast<long>(f), shapes[i].mesh.material_ids[f]);

      index_offset += fnum;
    }

    printf("shape[%ld].num_tags: %lu\n", static_cast<long>(i),      static_cast<unsigned long>(shapes[i].mesh.tags.size()));
    for (size_t t = 0; t < shapes[i].mesh.tags.size(); t++)
    {
      printf("  tag[%ld] = %s ", static_cast<long>(t),        shapes[i].mesh.tags[t].name.c_str());
      printf(" ints: [");
      for (size_t j = 0; j < shapes[i].mesh.tags[t].intValues.size(); ++j)
      {
        printf("%ld", static_cast<long>(shapes[i].mesh.tags[t].intValues[j]));
        if (j < (shapes[i].mesh.tags[t].intValues.size() - 1))
        {
          printf(", ");
        }
      }
      printf("]");

      printf(" floats: [");
      for (size_t j = 0; j < shapes[i].mesh.tags[t].floatValues.size(); ++j)
      {
        printf("%f", static_cast<const double>( shapes[i].mesh.tags[t].floatValues[j]));
        if (j < (shapes[i].mesh.tags[t].floatValues.size() - 1))
        {
          printf(", ");
        }
      }
      printf("]");

      printf(" strings: [");
      for (size_t j = 0; j < shapes[i].mesh.tags[t].stringValues.size(); ++j)
      {
        printf("%s", shapes[i].mesh.tags[t].stringValues[j].c_str());
        if (j < (shapes[i].mesh.tags[t].stringValues.size() - 1))
        {
          printf(", ");
        }
      }
      printf("]");
      printf("\n");
    }
  }

  for (size_t i = 0; i < materials.size(); i++) {
    printf("material[%ld].name = %s\n", static_cast<long>(i), materials[i].name.c_str());
    printf("  material.Ka = (%f, %f ,%f)\n", static_cast<const double>(materials[i].ambient[0]), static_cast<const double>(materials[i].ambient[1]), static_cast<const double>(materials[i].ambient[2]));
    printf("  material.Kd = (%f, %f ,%f)\n",
      static_cast<const double>(materials[i].diffuse[0]), static_cast<const double>(materials[i].diffuse[1]), static_cast<const double>(materials[i].diffuse[2]));
    printf("  material.Ks = (%f, %f ,%f)\n",
      static_cast<const double>(materials[i].specular[0]),static_cast<const double>(materials[i].specular[1]),  static_cast<const double>(materials[i].specular[2]));
    printf("  material.Tr = (%f, %f ,%f)\n",
      static_cast<const double>(materials[i].transmittance[0]), static_cast<const double>(materials[i].transmittance[1]), static_cast<const double>(materials[i].transmittance[2]));
    printf("  material.Ke = (%f, %f ,%f)\n",
      static_cast<const double>(materials[i].emission[0]), static_cast<const double>(materials[i].emission[1]), static_cast<const double>(materials[i].emission[2]));
    printf("  material.Ns = %f\n",
      static_cast<const double>(materials[i].shininess));
    printf("  material.Ni = %f\n", static_cast<const double>(materials[i].ior));
    printf("  material.dissolve = %f\n",  static_cast<const double>(materials[i].dissolve));
    printf("  material.illum = %d\n", materials[i].illum);
    printf("  material.map_Ka = %s\n", materials[i].ambient_texname.c_str());
    printf("  material.map_Kd = %s\n", materials[i].diffuse_texname.c_str());
    printf("  material.map_Ks = %s\n", materials[i].specular_texname.c_str());
    printf("  material.map_Ns = %s\n",
      materials[i].specular_highlight_texname.c_str());
    printf("  material.map_bump = %s\n", materials[i].bump_texname.c_str());
    printf("    bump_multiplier = %f\n", static_cast<const double>(materials[i].bump_texopt.bump_multiplier));
    printf("  material.map_d = %s\n", materials[i].alpha_texname.c_str());
    printf("  material.disp = %s\n", materials[i].displacement_texname.c_str());
    printf("  <<PBR>>\n");
    printf("  material.Pr     = %f\n", static_cast<const double>(materials[i].roughness));
    printf("  material.Pm     = %f\n", static_cast<const double>(materials[i].metallic));
    printf("  material.Ps     = %f\n", static_cast<const double>(materials[i].sheen));
    printf("  material.Pc     = %f\n", static_cast<const double>(materials[i].clearcoat_thickness));
    printf("  material.Pcr    = %f\n", static_cast<const double>(materials[i].clearcoat_thickness));
    printf("  material.aniso  = %f\n", static_cast<const double>(materials[i].anisotropy));
    printf("  material.anisor = %f\n", static_cast<const double>(materials[i].anisotropy_rotation));
    printf("  material.map_Ke = %s\n", materials[i].emissive_texname.c_str());
    printf("  material.map_Pr = %s\n", materials[i].roughness_texname.c_str());
    printf("  material.map_Pm = %s\n", materials[i].metallic_texname.c_str());
    printf("  material.map_Ps = %s\n", materials[i].sheen_texname.c_str());
    printf("  material.norm   = %s\n", materials[i].normal_texname.c_str());
    std::map<std::string, std::string>::const_iterator it(
      materials[i].unknown_parameter.begin());
    std::map<std::string, std::string>::const_iterator itEnd(
      materials[i].unknown_parameter.end());

    for (; it != itEnd; it++) {
      printf("  material.%s = %s\n", it->first.c_str(), it->second.c_str());
    }
    printf("\n");
  }
}
*/

// ------------------------------------------------------------------------------------
bool TestLoadObj(const char* filename, const char* basepath = NULL, bool triangulate = false)
{
    std::cout << "Loading " << filename << std::endl;

    //tinyobj::attrib_t attrib;
    //std::vector<tinyobj::shape_t> shapes;
    //std::vector<tinyobj::material_t> materials;

    timerutil t;
    t.start();
    std::string err;

    //bool ret = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, filename, basepath, triangulate);
    const aiScene* scene = aiImportFile(filename, 0 /*FLAGIMPORT*/);

    t.end();
    printf("Parsing time: %lu [msecs]\n", t.msec());

    if (!err.empty())
    {
        std::cerr << err << std::endl;
    }

    if (!scene)
    {
        printf("Failed to load/parse %s\n", filename);
        return false;
    }

    //PrintInfo(attrib, shapes, materials);

    return true;
}

// ------------------------------------------------------------------------------------
// Find best color amoung all color blend
colorblend FindBestColor(color colorA)
{
    int minerror = 55555555;
    int bestindex = 0;

    // Parse all blend color and compute error.
    for (int i = 0; i < gColorBlendNumber; i++)
    {
        int error = AllColorBlend[i].getdiff(colorA);

        if (error < minerror)
        {
            minerror = error;
            bestindex = i;
        }
    }
    return AllColorBlend[bestindex];
}

// ------------------------------------------------------------------------------------
void ComputeBlendColor()
{
    int i, j, k;

    for (i = 0; i < FINALCOLORS; i++)
    {
        //color colorA = AllColors[i];

        // Do blend with all colors, but not me
        for (j = 0; j < FINALCOLORS; j++)
        {
            if (i == j)
                continue;

            //color colorB = AllColors[j];

            // Do computing for all values from 0% to 87.5% (8 steps). 100% is not required.
#define DITHERSTEP (100.0f / 8.0f)
            colorblend mycolorblend;

            for (k = 0; k < 8; k++)
            {
                mycolorblend.set(i, j, k, DITHERSTEP);

                // Store the color
                AllColorBlend[gColorBlendNumber] = mycolorblend;
                gColorBlendNumber++;
            }

        }

    }
}

// ------------------------------------------------------------------------------------
void writefromdithertab(color color1, color color2, char* dithertab, unsigned char* pixels)
{
    int i;
    int j;
    for (j = 0; j < 4; j++)
    {
        for (i = 0; i < 4; i++)
        {
            if (dithertab[0] == 1)
                color1.writetobuffer(pixels);
            else
                color2.writetobuffer(pixels);
            pixels += 3;
            dithertab++;
        }
        // Next line
        pixels += ((128 - 4) * 3);
    }
}

// ------------------------------------------------------------------------------------
// Write 4x4 color into a 128 width picture
void WriteColorBlendToPicture(int x, int y, colorblend _color, unsigned char* pixels)
{
    pixels += ((y * 4 * 128 * 3) + (x * 4 * 3));

    // Write a 4x4 block at position x,y in the picture
    int index1 = _color.indexcolor1;
    color color1 = AllColors[index1];
    int index2 = _color.indexcolor2;
    color color2 = AllColors[index2];
    char dithertab0[16] = { 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1 };
    char dithertab1[16] = { 1,1,1,2, 1,1,1,1, 1,2,1,1, 1,1,1,1 };
    char dithertab2[16] = { 1,2,1,2, 1,1,1,1, 1,2,1,2, 1,1,1,1 };
    char dithertab3[16] = { 1,2,1,2, 1,1,2,1, 1,2,1,2, 2,1,1,1 };
    char dithertab4[16] = { 1,2,1,2, 2,1,2,1, 1,2,1,2, 2,1,2,1 };
    char dithertab5[16] = { 1,2,2,1, 2,1,2,2, 2,1,1,2, 2,2,2,1 };
    char dithertab6[16] = { 2,1,2,1, 2,2,2,2, 2,1,2,1, 2,2,2,2 };
    char dithertab7[16] = { 2,1,2,2, 2,2,2,2, 2,2,2,1, 2,2,2,2 };
    char dithertab8[16] = { 2,2,2,2, 2,2,2,2, 2,2,2,2, 2,2,2,2 };

    if (_color.ditherlevel == 0) writefromdithertab(color1, color2, dithertab0, pixels);
    else if (_color.ditherlevel == 1) writefromdithertab(color1, color2, dithertab1, pixels);
    else if (_color.ditherlevel == 2) writefromdithertab(color1, color2, dithertab2, pixels);
    else if (_color.ditherlevel == 3) writefromdithertab(color1, color2, dithertab3, pixels);
    else if (_color.ditherlevel == 4) writefromdithertab(color1, color2, dithertab4, pixels);
    else if (_color.ditherlevel == 5) writefromdithertab(color1, color2, dithertab5, pixels);
    else if (_color.ditherlevel == 6) writefromdithertab(color1, color2, dithertab6, pixels);
    else if (_color.ditherlevel == 7) writefromdithertab(color1, color2, dithertab7, pixels);
    else if (_color.ditherlevel == 8) writefromdithertab(color1, color2, dithertab8, pixels);
}

// --------------------------------------------------
// Blender save FBX with default coordinates change ( -Z Forward and Y up)
// X right, Y up, Z forward near.
// We want
// W right, Y down, Z far
// So need to negate Z and negate Y.
void ChangeCoordinateSystem(aiVector3D& vert)
{
    //vert.y *= -1.0f;
    //vert.z *= -1.0f;
}

int FindOrAddVertex(std::vector<aiVector3D>& VerticesIndexed, aiVector3D vertex)
{
    auto result = std::find(VerticesIndexed.begin(), VerticesIndexed.end(), vertex);

    if (result != VerticesIndexed.end()) // found
    {
        int index = (int)(result - VerticesIndexed.begin());
        return index;
    }
    else // Not found, so insert
    {
        VerticesIndexed.push_back(vertex);
        return (int)(VerticesIndexed.size() - 1);
    }
}

class DS_Face
{
public:
    int index[4];
    color facecolor;
    int matindex;
    int indexnormal;
};


// ------------------------------------------------------------------------------------
bool Load3D(const char* filename, bool triangulate = false)
{
    std::cout << "Loading " << filename << std::endl;

    //tinyobj::attrib_t attrib;
    //std::vector<tinyobj::shape_t> shapes;
    //std::vector<tinyobj::material_t> materials;

    timerutil t;
    t.start();
    std::string err;

    //bool ret = tinyobj::LoadObj(&attrib, &shapes, &materials, &err, filename, basepath, triangulate);
    const aiScene* scene = aiImportFile(filename, 0 /*FLAGIMPORT*/);
    t.end();
    printf("Parsing time: %lu [msecs]\n", t.msec());

    if (!err.empty())
    {
        std::cerr << err << std::endl;
    }

    if (!scene)
    {
        printf("Failed to load/parse 3d file models/%s\n", filename);
        return false;
    }

    //PrintInfo(attrib, shapes, materials);

    // Here we have 3D obj.
    // -- We are going to count how many faces for each materials
    int* materialsstatsfaces = NULL;
    int nbmaterials;
    nbmaterials = scene->mNumMaterials;

    if (nbmaterials > 0)
    {
        materialsstatsfaces = new int[nbmaterials];
        for (int i = 0; i < nbmaterials; i++)
            materialsstatsfaces[i] = 0;

        int nummesh = scene->mNumMeshes;

        for (int meshid = 0; meshid < nummesh; meshid++)
        {
            // Parse faces and count
            int nbfaces = scene->mMeshes[meshid]->mNumFaces;
            int matid = scene->mMeshes[meshid]->mMaterialIndex;
            materialsstatsfaces[matid] += nbfaces;
        }
    }
    else
    {
        // No mat, we exit
        printf("Missing material on model");
        exit(0);
    }

    // -- Read all infos about 3D. Vectices and normals.
    // Search to reduce number of vertices.
    // -- Vertices and normals shared for all objects
    std::vector<aiVector3D> VerticesIndexed;
    std::vector<aiVector3D> NormalsIndexed;
    std::vector<DS_Face> Faces;

    // -- Parse Objects ---------------------------
    // Record faces for each, and create unique Vertice buffer
    int nbobjects = scene->mRootNode->mNumChildren;
    for (int i = 0; i < nbobjects; i++)
    {
        aiNode* node = scene->mRootNode->mChildren[i];
        aiString name = node->mName;

        printf(" (%d) Name : %s\n", i, name.C_Str());
        //DS_Object& sceneobject = mScene.objects[i];

        // Transformations
        aiMatrix4x4 transformation = node->mTransformation;
        aiMatrix4x4 transformationrot = transformation;
        // Remove translation
        transformationrot.a4 = 0.0f;
        transformationrot.b4 = 0.0f;
        transformationrot.c4 = 0.0f;
 
        // Faces
        if (node->mNumMeshes == 0)
        {
            printf(" Warning, noMesh, skipping\n");
            continue;
        }
        int totalfaces = 0; // Count faces
        for (int meshid = 0; meshid < node->mNumMeshes; meshid++)
        {
            int indexmesh = node->mMeshes[meshid];
            aiMesh* mesh = scene->mMeshes[indexmesh];
            totalfaces += mesh->mNumFaces;
        }
        // Alloc nb faces
        //sceneobject.nbfaces = totalfaces;
        //sceneobject.faces = new DS_Face[totalfaces]; // Todo manage face with count not egal 4

        for (int meshid = 0; meshid < node->mNumMeshes; meshid++) // All meshes
        {
            int indexmesh = node->mMeshes[meshid];
            printf(" Index mesh = %d\n", indexmesh);
            aiMesh* mesh = scene->mMeshes[indexmesh];
            int matindex = mesh->mMaterialIndex;
            color currentcolor = AllColors[matindex];
            int NbFaces = mesh->mNumFaces;
            int NbFacesRecorded = 0; // If some faces are ignored (vertices not 3 or 4)
            for (int f = 0; f < NbFaces; f++)
            {
                aiFace face = mesh->mFaces[f];
                int numIndices = face.mNumIndices;
                bool isquad = (numIndices == 4);
                if (numIndices == 3 || numIndices == 4)
                {
                    aiVector3D newvert;
                    // Search or add index
                    //aiVector3D mesh->mVertices
                    // Remap indices to reduce used vertices (global array, not per mesh).s
                    newvert = transformation * mesh->mVertices[face.mIndices[0]];
                    ChangeCoordinateSystem(newvert);
                    int index0 = FindOrAddVertex(VerticesIndexed, newvert);
                    newvert = transformation * mesh->mVertices[face.mIndices[1]];
                    ChangeCoordinateSystem(newvert);
                    int index1 = FindOrAddVertex(VerticesIndexed, newvert);
                    newvert = transformation * mesh->mVertices[face.mIndices[2]];
                    ChangeCoordinateSystem(newvert);
                    int index2 = FindOrAddVertex(VerticesIndexed, newvert);

                    int index3 = -1;
                    if (isquad)
                    {
                        newvert = transformation * mesh->mVertices[face.mIndices[3]];
                        ChangeCoordinateSystem(newvert);
                        index3 = FindOrAddVertex(VerticesIndexed, newvert);
                    }

                    printf("  Face %d : %d Indices, %d %d %d %d (mat %d)\n", Faces.size(), numIndices, index0, index1, index2, index3, matindex);
                    DS_Face Currentface;
                    Currentface.index[0] = index0;
                    Currentface.index[1] = index1;
                    Currentface.index[2] = index2;
                    Currentface.index[3] = index3;

                    // Display vertices
                    printf("  Vertices\n");
                    printf("   %.1f %.1f %.1f \n", VerticesIndexed[index0].x, VerticesIndexed[index0].y, VerticesIndexed[index0].z);
                    printf("   %.1f %.1f %.1f \n", VerticesIndexed[index1].x, VerticesIndexed[index1].y, VerticesIndexed[index1].z);
                    printf("   %.1f %.1f %.1f \n", VerticesIndexed[index2].x, VerticesIndexed[index2].y, VerticesIndexed[index2].z);
                    if (index3 > -1)
                        printf("   %.1f %.1f %.1f \n", VerticesIndexed[index3].x, VerticesIndexed[index3].y, VerticesIndexed[index3].z);

                    // -- Add face color
                    Currentface.facecolor = currentcolor;
                    Currentface.matindex = matindex;

                    // Add face normals
                    // Compute normal. cross product of two vector of face
                    //Vec4 p0 = Vec4(VerticesIndexed[index0].x, VerticesIndexed[index0].y, VerticesIndexed[index0].z);
                    //Vec4 p1 = Vec4(VerticesIndexed[index1].x, VerticesIndexed[index1].y, VerticesIndexed[index1].z);
                    //Vec4 p2 = Vec4(VerticesIndexed[index2].x, VerticesIndexed[index2].y, VerticesIndexed[index2].z);
                    //Vec4 v1 = p1 - p0;
                    //Vec4 v2 = p2 - p1;
                    //Vec4 normal = Vec4::Cross(v1, v2);
                    //normal.Normalize3();
                    //mesh->
                    newvert = transformationrot * mesh->mNormals[face.mIndices[0]];
                    newvert.Normalize();
                    ChangeCoordinateSystem(newvert);
                    int indexnormal = FindOrAddVertex(NormalsIndexed, newvert);

                    //int indexnormal = FindOrAddVertex(NormalsIndexed, aiVector3D((ai_real)normal.x, (ai_real)normal.y, (ai_real)normal.z));
                    Currentface.indexnormal = indexnormal;
                    NbFacesRecorded++;
                    Faces.push_back(Currentface);
                }
                else
                {
                    printf("  Face is not a triangle nor a quad ! (indices %d)\n",numIndices);
                }

            } // All faces
        } // all meshes
        // Update total number of faces, could be less
    } // Parse all objects.

    // Now create a picture with pixels represented by materials and number of faces.
    // Each material have its colors, we add 16 pixels * number face using it.
    // Then 16 pixels for brightness decreasing to 0
    // And 16 pixels for brightness increasing.
    // So we create a picture of 16 width.
    // and height : Total of faces + 2*nb of mats.
    int facenumber;
    facenumber = 0;
    int nbusedmaterials = nbmaterials;
    for (int i = 0; i < nbmaterials; i++)
    {
        facenumber += materialsstatsfaces[i];
        if (materialsstatsfaces[i] == 0)
            nbusedmaterials--;
    }

    int totalnumberoflines = facenumber + 2 * nbusedmaterials; // +10; // Add 20 lines of black and white at end

    // Allocated a picture
    image_t myimage;
    myimage.w = 16;
    myimage.h = totalnumberoflines;
    // Alloc pixels.
    myimage.pix = (unsigned char*)malloc(myimage.h * myimage.w * 3);
    // Fill picture
    unsigned char* buffer;
    buffer = myimage.pix;
    for (int i = 0; i < nbmaterials; i++)
    {
        // Get material color
        const aiMaterial* mat = scene->mMaterials[i];
        aiColor3D assimpcolor(0.f, 0.f, 0.f);
        mat->Get(AI_MATKEY_COLOR_DIFFUSE, assimpcolor);

        unsigned char red = (int)(assimpcolor.r * 255.0f);
        unsigned char green = (int)(assimpcolor.g * 255.0f);
        unsigned char blue = (int)(assimpcolor.b * 255.0f);

        color matcolor = color(red, green, blue);
        // number of face using this material
        int nbfaces = materialsstatsfaces[i];
        if (nbfaces == 0)
            continue;
        // Write full lines with this.
        for (int j = 0; j < 16 * nbfaces; j++)
        {
            matcolor.writetobuffer(buffer);
            buffer += 3;
        }
        // Write 16 pixels with all variation.
        float brightstep = 1 / 16.0f;
        for (int j = 16; j > 0; j--)
        {
            matcolor.writetobufferwithbrightness(buffer, brightstep * j);
            buffer += 3;
        }
        for (int j = 16; j < 32; j++)
        {
            matcolor.writetobufferwithbrightness(buffer, brightstep * j);
            buffer += 3;
        }
    }
    //  Add 10 lines of white

    color colowhite = color(255, 255, 255);

    /*
    for (int j = 0; j < 10 * 16; j++)
    {
        colowhite.writetobuffer(buffer);
        buffer += 3;
    }
    */

    color colorblack = color(0, 0, 0);
    /*
    * Add 10 lines of black
    for (int j = 0; j < 10 * 16; j++)
    {
      colorblack.writetobuffer(buffer);
      buffer += 3;
    }
    */

    write_ppm(&myimage, (char*)"ResultBeforeQuantization.ppm");

    unsigned char result_colors[(FINALCOLORS - 0) * 3];
    color_quant(&myimage, (FINALCOLORS - 0), result_colors);

    // Create and save image (for debug purpose)
    image_t myoutputimage;
    myoutputimage.w = (FINALCOLORS - 1);
    myoutputimage.h = 1;
    myoutputimage.pix = result_colors;
    write_ppm(&myoutputimage, (char*)"ResultafterQuantization.ppm");
    free(myimage.pix);

    // Sort colors from their brightness (summ of three components)
    AllColors[0] = colorblack; // First color is black (transparent) color
    for (int i = 1; i < FINALCOLORS; i++)
    {
        AllColors[i].r = result_colors[(i - 1) * 3 + 0];
        AllColors[i].g = result_colors[(i - 1) * 3 + 1];
        AllColors[i].b = result_colors[(i - 1) * 3 + 2];
        AllColors[i].convertto16bits();
    }
    // Sort array
    std::qsort(AllColors, FINALCOLORS, sizeof(color), compare);
    // Here the colors are sorted
    colorblend::AllColors = AllColors; // Static member, all colorblend will now our array
    // Force highest color to be White
    //AllColors[FINALCOLORS - 1] = color(255, 255, 255);

    // ---- Write result
    unsigned char bufferoutput[10240];
    unsigned char* pBuffer = bufferoutput;
    // Header is 10 bytes
    pBuffer += 10;
    // -- Write vertices
    // Vertices: N*6bytes
    // W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
    int numvertices = VerticesIndexed.size(); // 3 value is one vertice, x y z
    FixedFloat MyFloat = FixedFloat(numvertices);
    MyFloat.writetobufferasint(bufferoutput); // Write number of vertices
    for (int i = 0; i < numvertices; i++)
    {
        MyFloat.set(VerticesIndexed[i].x);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;
        MyFloat.set(VerticesIndexed[i].y);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;
        MyFloat.set(VerticesIndexed[i].z);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;

        printf("Vertex %03d : %.2f %.2f %.2f\n", i, VerticesIndexed[i].x, VerticesIndexed[i].y, VerticesIndexed[i].z);
    }
    // Write normals
    // Normals: N*6bytes
    // W,W,W : X,Y,Z in 8:8 format (-128 to 128). Centered on 0. 6 bytes per element
    int numnormals = NormalsIndexed.size(); // 3 value is one vertice, x y z
    MyFloat.set(numnormals);
    MyFloat.writetobufferasint(bufferoutput + 2); // Write number of vertices
    for (int i = 0; i < numnormals; i++)
    {
        MyFloat.set(NormalsIndexed[i].x);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;
        MyFloat.set(NormalsIndexed[i].y);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;
        MyFloat.set(NormalsIndexed[i].z);
        MyFloat.writetobufferas88(pBuffer);
        pBuffer += 2;

        printf("Normal %03d : %.2f %.2f %.2f\n", i, NormalsIndexed[i].x, NormalsIndexed[i].y, NormalsIndexed[i].z);
  
    }
    // -- Write quads
    // W : Nb Quads (Max 256)
    // Quads: N*6bytes
    // B B B B B B: Index1,2,3,4, color, Normal
    int numfaces;
    numfaces = Faces.size();
    int numquad = 0;
    int offsetindices = 0;
    for (int i = 0; i < numfaces; i++)
    {
        if (Faces[i].index[3] != -1)
        {
            int objmaterialindex = Faces[i].matindex;
            // Get material color
            //const aiMaterial* mat = scene->mMaterials[objmaterialindex];
            //aiColor3D assimpcolor(0.f, 0.f, 0.f);
            //mat->Get(AI_MATKEY_COLOR_DIFFUSE, assimpcolor);
            //unsigned char red = (int)(assimpcolor.r * 255.0f);
            //unsigned char green = (int)(assimpcolor.g * 255.0f);
            //unsigned char blue = (int)(assimpcolor.b * 255.0f);
            //color objcolor = color(red, green, blue);
            //int materialindex = FindBestRealColor(objcolor);

            int indice1, indice2, indice3, indice4;
            indice1 = Faces[i].index[0];
            indice2 = Faces[i].index[1];
            // TODO: Invert indice 3 and 4, to be ready for amiga display
            indice4 = Faces[i].index[2];
            indice3 = Faces[i].index[3];

            MyFloat.set(indice1);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(indice2);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(indice3);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(indice4);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            // Write material Id
            MyFloat.set(objmaterialindex);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            // Write normal id
            MyFloat.set(Faces[i].indexnormal);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            numquad++;
        }
        //offsetindices += 0; // shapes[0].mesh.num_face_vertices[i];
    }
    MyFloat.set(numquad);
    MyFloat.writetobufferasint(bufferoutput + 4); // Write number of quads
    // Add end marker
    MyFloat.set(0xFFFF);
    MyFloat.writetobufferasint(pBuffer);
    pBuffer += 2;
    MyFloat.writetobufferasint(pBuffer);
    pBuffer += 2;

    // -- Write Triangles
    // W : Nb Triangles (Max 256)
    // Triangles: N*6bytes
    // B B B B : Index 1 2 3, Dummy, Color, Normal
    int numtriangles = 0;
    //offsetindices = 0;
    for (int i = 0; i < numfaces; i++)
    {
        int objmaterialindex = Faces[i].matindex;
        // Get material color
        //const aiMaterial* mat = scene->mMaterials[objmaterialindex];
        //aiColor3D assimpcolor(0.f, 0.f, 0.f);
        //mat->Get(AI_MATKEY_COLOR_DIFFUSE, assimpcolor);
        //unsigned char red = (int)(assimpcolor.r * 255.0f);
        //unsigned char green = (int)(assimpcolor.g * 255.0f);
        //unsigned char blue = (int)(assimpcolor.b * 255.0f);
        //color objcolor = color(red, green, blue);
        //int materialindex = FindBestRealColor(objcolor);

        if (Faces[i].index[3] == -1)
        {
            int indice1, indice2, indice3, indice4;
            indice1 = Faces[i].index[0];
            indice2 = Faces[i].index[1];
            indice3 = Faces[i].index[2];
            //indice3 = shapes[0].mesh.indices[offsetindices + 3].vertex_index;

            MyFloat.set(indice1);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(indice2);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(indice3);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;
            MyFloat.set(0); // Dummy
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            // Write material Id
            MyFloat.set(objmaterialindex);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            // Write normal id
            MyFloat.set(Faces[i].indexnormal); // Index of first point normal
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer++;

            numtriangles++;
        }
        //offsetindices += 0; // shapes[0].mesh.num_face_vertices[i];
    }
    MyFloat.set(numtriangles);
    MyFloat.writetobufferasint(bufferoutput + 6); // Write number of triangles
                                                  // Add end marker
    MyFloat.set(0xFFFF);
    MyFloat.writetobufferasint(pBuffer);
    pBuffer += 2;
    MyFloat.writetobufferasint(pBuffer);
    pBuffer += 2;

    // -- Write Base Palette
    // Base palette: 
    // W : 8 colors ( 16 bytes)
    for (int i = 0; i < FINALCOLORS; i++)
    {
        printf("Palette %d : %d %d %d\n", i, AllColors[i].r, AllColors[i].g, AllColors[i].b);
        AllColors[i].writetobufferas16bits(pBuffer);
        pBuffer += 2;
    }

    // Compute all blended colors
    ComputeBlendColor();

    // -- Write Colors
    // W : NB Colors (Max 256)
    // Color table: N colordithered
    // For each color, 32 colorsdithered. Color 1, color 2, Dither id. = 1 byte, dummy byte
    // B B B B
    // N*32*2 = N*64 bytes per color.

    // Create image for debug purpose
    int picturesizex;
    int picturesizey;
    unsigned char* pixels;
    picturesizey = 4 * nbmaterials;
    picturesizex = 4 * 16 * 2;
    pixels = (unsigned char*)malloc(picturesizex * picturesizey * 3);

    //Compute brightness of all color from base color and available dithering.
    for (int i = 0; i < nbmaterials; i++)
    {
        // Get material color
        const aiMaterial* mat = scene->mMaterials[i];
        aiColor3D assimpcolor(0.f, 0.f, 0.f);
        mat->Get(AI_MATKEY_COLOR_DIFFUSE, assimpcolor);
        unsigned char red = (int)(assimpcolor.r * 255.0f);
        unsigned char green = (int)(assimpcolor.g * 255.0f);
        unsigned char blue = (int)(assimpcolor.b * 255.0f);

        // number of face using this material
        //int nbfaces = materialsstatsfaces[i];
        //if (nbfaces == 0)
        //    continue;

        // Do first light from 0 to 100% in 16 steps
        // Then 100% to 200% in second step
        for (int j = 0; j < 16; j++)
        {
            float coef = (float)j * (1.0f / (16.0f - 1.0f));
            color colorToFind = color(red, green, blue);
            colorToFind.setandaddbrighnessfloat(coef);
            colorblend colorblend = FindBestColor(colorToFind);
            WriteColorBlendToPicture(j, i, colorblend, pixels); // i and j is position as 4x4 block in the picture.
            // Write to data file
            MyFloat.set(colorblend.indexcolor1);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(colorblend.indexcolor2);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(colorblend.ditherlevel);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(0);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
        }
        for (int j = 0; j < 16; j++)
        {
            float coef = 1.0f + ((float)j * (1.0f / (16.0f - 1.0f)));
            color colorToFind = color(red, green, blue);
            colorToFind.setandaddbrighnessfloat(coef);
            colorblend colorblend = FindBestColor(colorToFind);
            WriteColorBlendToPicture(16 + j, i, colorblend, pixels); // i and j is position as 4x4 block in the picture.
            // Write to data file
            MyFloat.set(colorblend.indexcolor1);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(colorblend.indexcolor2);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(colorblend.ditherlevel);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
            MyFloat.set(0);
            MyFloat.writetobufferaschar(pBuffer);
            pBuffer += 1;
        }
    }

    // Create and save image (for debug purpose)
    image_t myoutputimage2;
    myoutputimage2.w = picturesizex;
    myoutputimage2.h = picturesizey;
    myoutputimage2.pix = pixels;
    write_ppm(&myoutputimage2, (char*)"ResultLightingColors.ppm");
    free(myoutputimage2.pix);

    // Save file
    FILE* fileouput;
    fileouput = fopen("Obj.bin", "wb");
    if (fileouput)
    {
        int size;
        size = pBuffer - bufferoutput;
        fwrite(bufferoutput, 1, size, fileouput);
        fclose(fileouput);
    }

    return true;
}



int main(int argc, char** argv)
{
    /*
    unsigned char buffer[256];
    unsigned char* pBuffer = buffer;
    FixedFloat float1 = FixedFloat(0.0f);
    FixedFloat float2 = FixedFloat(0.5f);
    FixedFloat float3 = FixedFloat(1.0f);
    FixedFloat float4 = FixedFloat(-0.5f);
    FixedFloat float5 = FixedFloat(-1.0f);
    FixedFloat float6 = FixedFloat(10.0f);
    float1.writetobufferas88(pBuffer);
    pBuffer += 2;
    float2.writetobufferas88(pBuffer);
    pBuffer += 2;
    float3.writetobufferas88(pBuffer);
    pBuffer += 2;
    float4.writetobufferas88(pBuffer);
    pBuffer += 2;
    float5.writetobufferas88(pBuffer);
    pBuffer += 2;
    float6.writetobufferasint(pBuffer);
    pBuffer += 2;
    */


    if (argc > 1)
    {
        bool result = Load3D(argv[1]);

        if (result)
        {
            // copy file
            system("copy Obj.bin d:\\Kristof\\Amiga_Dev\\WinUAE4210_x64\\dh1\\Sources\\Obj.bin");

        }

    }

    return 0;
}
