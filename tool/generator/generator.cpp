// Generator
//
// A small (and very crappy) tool to generate the map tile images used by planetary 
// (https://github.com/thijskruithof/planetary)
//
// This will:
// 1. load a base albedo map and a base elevation map (typically very big images)
// 2. render shadows into the albedo map (very slow!)
// 3. render a gradient at the border of the images
// 4. write out albedo images and elevation map meshes of fixed size (and also for each lod level)
//
//
// Copyright(C) 2020 Thijs Kruithof
//
// This program is free software : you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.


#include "lodepng.h"
#include "toojpeg\toojpeg.h"
#include "math.h"

#include <windows.h>
#undef NDEBUG
#include <assert.h>


#define ALBEDO_TILE_SIZE 512
#define ELEVATION_TILE_SIZE 128

//#define ALBEDO_BASE_IMAGE_FN "c:\\temp\\albedo_0_0.png"
//#define ELEVATION_BASE_IMAGE_FN "c:\\temp\\elevation_0_0.png"
//#define ALBEDO_BASE_IMAGE_FN "c:\\temp\\albedo_16_0.png"
//#define ELEVATION_BASE_IMAGE_FN "c:\\temp\\elevation_16_0.png"
//#define ALBEDO_BASE_IMAGE_FN "c:\\temp\\albedo_30_0.png"
//#define ELEVATION_BASE_IMAGE_FN "c:\\temp\\elevation_30_0.png"
//#define ALBEDO_BASE_IMAGE_FN "c:\\temp\\albedo_24_0.png"
//#define ELEVATION_BASE_IMAGE_FN "c:\\temp\\elevation_24_0.png"

#define BASE_PATH "d:\\Thijs\\Projects\\planetary\\unversioned\\"

#define OUTPUT_BASE_PATH BASE_PATH ## "Output\\"

#define ALBEDO_BASE_IMAGE_FN BASE_PATH ## "base_albedo.png"
#define ELEVATION_BASE_IMAGE_FN BASE_PATH ## "base_elevation.png"

#define SUN_HEADING DEG_TO_RAD(180.0f)
#define SUN_PITCH DEG_TO_RAD(25.0f)
#define SUN_HEADING_SPREAD DEG_TO_RAD(2.0f)
#define SUN_PITCH_SPREAD DEG_TO_RAD(0.5f)

#define NUM_SHADOW_RENDERER_THREADS 8

#define ELEVATION_MAP_PIXELOFFSET_X 0
#define ELEVATION_MAP_PIXELOFFSET_Y 0

#define SHADOW_AMOUNT 0.40f

#define ENABLE_RENDER_SHADOWS 0
#define ENABLE_RENDER_BORDERGRADIENT 0

#define WRITE_ALBEDO_FILES 0
#define WRITE_ELEVATION_FILES 0
#define WRITE_ELEVATION_INDICES_FILE 1

// Source map images
unsigned int gMapWidth;
unsigned int gMapHeight;
Vec2 gMapSize;

unsigned char* gAlbedoMap;
unsigned char* gElevationMap;
float* gElevationMapF;


// Returns elevation [0..255], bilinear filtered
__forceinline float getElevation(const Vec3& pos)
{
    int px = (int)pos.mX;
    int py = (int)pos.mY;
    float wx = pos.mX - (float)px;
    float wy = pos.mY - (float)py;

    int offset = px + py * gMapWidth;

    return
        (1.0f - wx) * (1.0f - wy) * gElevationMapF[offset] +
        wx * (1.0f - wy) * gElevationMapF[offset + 1] +
        (1.0f - wx) * wy * gElevationMapF[offset + gMapWidth] +
        wx * wy * gElevationMapF[offset + gMapWidth + 1];

}



bool intersects(const Vec2& startPos, const Vec3& direction)
{
    assert(direction.mZ > 0.0f);

    Vec3 pos(startPos, 0.0f);
    pos.mZ = getElevation(pos) + 2.0f;

    float len2D = direction.XY().Length();

    // 2 pixel steps
    Vec3 step = direction * (1.0f / len2D);

    while (true)
    {
        pos += step;

        if (pos.mX < 1.0f || pos.mX >= gMapSize.mX - 3.0f ||
            pos.mY < 1.0f || pos.mY >= gMapSize.mY - 3.0f)
            return false;

        float elevation = getElevation(pos);

        if (pos.mZ < elevation - 5.0f)
            return true; // Into the terrain :'(

        if (pos.mZ > 255.0f)
            return false; // Above the max elevation
    }

    return false;
}


FILE* gSaveImageFile = nullptr;

void saveImage24(const unsigned char* src, const char* filename, int x, int y, int width, int height, int mapWidth, int mapHeight, unsigned char* tempBuffer)
{
    assert(x >= 0 && x <= (int)mapWidth - width);
    assert(y >= 0 && y <= (int)mapHeight - height);

    unsigned char* dest = tempBuffer;

    for (int ty = 0; ty < height; ++ty)
    {
        int srcPixeloffset = x + (y + ty)*mapWidth;
        
        // Copy a row (from RGBA to RGB)
        for (int tx = 0; tx < width; ++tx)
        {
            *(dest++) = src[(srcPixeloffset + tx) * 4];
            *(dest++) = src[(srcPixeloffset + tx) * 4 + 1];
            *(dest++) = src[(srcPixeloffset + tx) * 4 + 2];
        }
    }

    // Clear bottom rows (if image is not square)
    for (int ty = height; ty < width; ++ty)
        memset(tempBuffer + ty * width * 3, 0, width * 3);

    assert(gSaveImageFile == nullptr);
    gSaveImageFile = nullptr;
    fopen_s(&gSaveImageFile, filename, "wb");
    assert(gSaveImageFile != nullptr);

    bool success = TooJpeg::writeJpeg(
        [](unsigned char oneByte) { fputc(oneByte, gSaveImageFile); },
        tempBuffer,
        width,
        width,
        true, // isRGB
        80, // quality
        false, // downsample
        ""
    );

    assert(success);

    fclose(gSaveImageFile);
    gSaveImageFile = nullptr;   
}



void saveImageF(const float* src, const char* filename, int x, int y, int width, int height, int mapWidth, int mapHeight, unsigned char* tempBuffer)
{
    assert(x >= 0 && x <= (int)mapWidth - width);
    assert(y >= 0 && y <= (int)mapHeight - height);

    for (int ty = 0; ty < height; ++ty)
    {
        for (int tx = 0; tx < width; ++tx)
        {
            float v = src[x + tx + (y + ty)*mapWidth];
            unsigned char r = (unsigned char)v;
            
            tempBuffer[tx + (ty*width)] = r;
        }
    }

    // Clear bottom rows (if image is not square)
    for (int ty = height; ty < width; ++ty)
        memset(tempBuffer + ty * width, 0, width);

    assert(gSaveImageFile == nullptr);
    gSaveImageFile = nullptr;
    fopen_s(&gSaveImageFile, filename, "wb");
    assert(gSaveImageFile != nullptr);

    bool success = TooJpeg::writeJpeg(
        [](unsigned char oneByte) { fputc(oneByte, gSaveImageFile); },
        tempBuffer,
        width,
        width,
        false, // isRGB
        70, // quality
        false, // downsample
        ""
    );

    assert(success);

    fclose(gSaveImageFile);
    gSaveImageFile = nullptr;
}


#pragma pack(push, 1)

struct Vertex
{
    float mPosX; // 0..1
    float mPosY; // 0..1
    float mPosZ; // 0..1
};

#pragma pack(pop)


void saveMesh(const float* src, const char* filename, int x, int y, int width, int height, int mapWidth, int mapHeight, Vertex* tempVertexBuffer)
{
    assert(x >= 0 && x <= (int)mapWidth - width);
    assert(y >= 0 && y <= (int)mapHeight - height);

    // Generate vertices
    for (int ty = 0; ty <= height; ++ty)
    {
        int tty = y + ty;
        if (tty >= mapHeight)
            tty = mapHeight - 1;

        for (int tx = 0; tx <= width; ++tx)
        {
            int ttx = x + tx;
            if (ttx >= mapWidth)
                ttx = mapWidth - 1;

            float v = src[ttx + tty*mapWidth];

            Vertex& vert = tempVertexBuffer[tx + ty*(width+1)];

            vert.mPosX = tx / (float)width;
            vert.mPosY = ty / (float)height;
            vert.mPosZ = v;
        }
    }
    
    FILE* f = nullptr;
    fopen_s(&f, filename, "wb");
    assert(f != nullptr);

    unsigned int w32 = width;
    unsigned int h32 = height;
    unsigned int numVertices = (width + 1)*(height + 1);

    // Output some basic details
    fwrite(&w32, 4, 1, f);
    fwrite(&h32, 4, 1, f);
    fwrite(&numVertices, 4, 1, f);

    // Output our buffers
    fwrite(tempVertexBuffer, numVertices, sizeof(Vertex), f);

    fclose(f);
}



void saveMeshIndices(const char* filename, int width, int height)
{
    assert(width == 128);
    assert(height == 128);
    unsigned short* tempIndexBuffer = new unsigned short[width*height*6];

    int quad = 0;
    for (int a6 = 0; a6 < 4; ++a6) /// 128x128
    {
        for (int a5 = 0; a5 < 4; ++a5) /// 64x64
        {
            for (int a4 = 0; a4 < 4; ++a4) /// 32x32
            {
                for (int a3 = 0; a3 < 4; ++a3) /// 16x16
                {
                    for (int a2 = 0; a2 < 4; ++a2) /// 8x8
                    {
                        for (int a1 = 0; a1 < 4; ++a1) /// 4x4
                        {
                            for (int a0 = 0; a0 < 4; ++a0) // 2x2
                            {
                                int x =
                                    (a0 % 2) +
                                    ((a1 % 2) << 1) +
                                    ((a2 % 2) << 2) +
                                    ((a3 % 2) << 3) +
                                    ((a4 % 2) << 4) +
                                    ((a5 % 2) << 5) +
                                    ((a6 % 2) << 6);
                                int y =
                                    ((a0 >> 1) % 2) +
                                    (((a1 >> 1) % 2) << 1) +
                                    (((a2 >> 1) % 2) << 2) +
                                    (((a3 >> 1) % 2) << 3) +
                                    (((a4 >> 1) % 2) << 4) +
                                    (((a5 >> 1) % 2) << 5) +
                                    (((a6 >> 1) % 2) << 6);

                                unsigned short v = x + y * (width + 1);

                                // Tri 0
                                tempIndexBuffer[quad * 6] = v;
                                tempIndexBuffer[quad * 6 + 1] = v + 1;
                                tempIndexBuffer[quad * 6 + 2] = v + width + 1;

                                // Tri 1
                                tempIndexBuffer[quad * 6 + 3] = v + 1;
                                tempIndexBuffer[quad * 6 + 4] = v + width + 2;
                                tempIndexBuffer[quad * 6 + 5] = v + width + 1;

                                quad++;
                            }
                        }
                    }
                }
            }
        }
    }

    assert(quad = width * height);


    FILE* f = nullptr;
    fopen_s(&f, filename, "wb");
    assert(f != nullptr);

    unsigned int w32 = width;
    unsigned int h32 = height;
    unsigned int numIndices = width * height * 6;

    // Output some basic details
    fwrite(&w32, 4, 1, f);
    fwrite(&h32, 4, 1, f);
    fwrite(&numIndices, 4, 1, f);

    // Output our buffers
    fwrite(tempIndexBuffer, numIndices, sizeof(unsigned short), f);

    fclose(f);

    delete[] tempIndexBuffer;
}



void half(unsigned char* src, unsigned int width, unsigned int height)
{
    unsigned int halfedWidth = width / 2;
    unsigned int halfedHeight = height / 2;
    unsigned char* halfed = (unsigned char*)malloc(halfedWidth*halfedHeight * 4);

    unsigned __int32* src32 = (unsigned __int32*)src;
    unsigned __int32* halfed32 = (unsigned __int32*)halfed;

    // Linear downsample
    for (int y = 0; y < (int)height; y += 2)
    {
        for (int x = 0; x < (int)width; x += 2)
        {
            unsigned __int32 a = src32[x + y * width];
            unsigned __int32 b = src32[x + y * width + 1];
            unsigned __int32 c = src32[x + (y+1) * width];
            unsigned __int32 d = src32[x + (y + 1) * width + 1];

            unsigned __int32 c0 = ((a & 0xff) + (b & 0xff) + (c & 0xff) + (d & 0xff)) / 4;
            unsigned __int32 c1 = ((((a >> 8) & 0xff) + ((b >> 8) & 0xff) + ((c >> 8) & 0xff) + ((d >> 8) & 0xff)) / 4) << 8;
            unsigned __int32 c2 = ((((a >> 16) & 0xff) + ((b >> 16) & 0xff) + ((c >> 16) & 0xff) + ((d >> 16) & 0xff)) / 4) << 16;
            unsigned __int32 c3 = ((((a >> 24) & 0xff) + ((b >> 24) & 0xff) + ((c >> 24) & 0xff) + ((d >> 24) & 0xff)) / 4) << 24;

            halfed32[x/2 + (y/2) * halfedWidth] = c3 | c2 | c1 | c0;
        }
    }

    // Copy back
    memcpy(src, halfed, halfedWidth*halfedHeight * 4);

    free(halfed);
}




void halfF(float* src, unsigned int width, unsigned int height)
{
    unsigned int halfedWidth = width / 2;
    unsigned int halfedHeight = height / 2;
    float* halfed = (float*)malloc(halfedWidth*halfedHeight * 4);

    // Linear downsample
    for (int y = 0; y < (int)height; y += 2)
    {
        for (int x = 0; x < (int)width; x += 2)
        {
            float a = src[x + y * width];
            float b = src[x + y * width + 1];
            float c = src[x + (y + 1) * width];
            float d = src[x + (y + 1) * width + 1];

            halfed[x / 2 + (y / 2) * halfedWidth] = (a + b + c + d) / 4.0f;
        }
    }

    // Copy back
    memcpy(src, halfed, halfedWidth*halfedHeight * 4);

    free(halfed);
}


struct ShadowRendererParams
{
    int startY;
    int endY;
    DWORD threadID;
};


Vec3 getHeadingPitchDirection(float heading, float pitch)
{
    return Vec3(cosf(heading)*cosf(pitch), sinf(heading)*cosf(pitch), sinf(pitch));
}


DWORD WINAPI ShadowThreadFunction(LPVOID lpParam)
{
    ShadowRendererParams* params = (ShadowRendererParams*)lpParam;

    Vec3 sunDirection[5];       
    sunDirection[0] = getHeadingPitchDirection(SUN_HEADING, SUN_PITCH);
    sunDirection[1] = getHeadingPitchDirection(SUN_HEADING + SUN_HEADING_SPREAD, SUN_PITCH);
    sunDirection[2] = getHeadingPitchDirection(SUN_HEADING - SUN_HEADING_SPREAD, SUN_PITCH);
    sunDirection[3] = getHeadingPitchDirection(SUN_HEADING, SUN_PITCH + SUN_PITCH_SPREAD);
    sunDirection[4] = getHeadingPitchDirection(SUN_HEADING, SUN_PITCH - SUN_PITCH_SPREAD);

    for (int y = params->startY; y <= params->endY; y++)
    {
        for (int x = 0; x < (int)gMapWidth; ++x)
        {
            Vec2 pos;
            pos.mX = min((float)x, gMapSize.mX - 2.0f);
            pos.mY = min((float)y, gMapSize.mY - 2.0f);

            float amount = 0.0f;

            if (intersects(pos, sunDirection[0])) amount += 1.0f;
            if (intersects(pos, sunDirection[1])) amount += 1.0f;
            if (intersects(pos, sunDirection[2])) amount += 1.0f;
            if (intersects(pos, sunDirection[3])) amount += 1.0f;
            if (intersects(pos, sunDirection[4])) amount += 1.0f;

            float intensity = 1.0f - amount * (SHADOW_AMOUNT / 5.0f);

            // Dim RGB
            gAlbedoMap[(x + y * gMapWidth) * 4] = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4] * intensity);
            gAlbedoMap[(x + y * gMapWidth) * 4 + 1] = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4 + 1] * intensity);
            gAlbedoMap[(x + y * gMapWidth) * 4 + 2] = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4 + 2] * intensity);
        }
    }

    return 0;
}



int main()
{
    unsigned error;
    
#if WRITE_ALBEDO_FILES
    printf("Loading albedo...\n");
    error = lodepng_decode32_file(&gAlbedoMap, &gMapWidth, &gMapHeight, ALBEDO_BASE_IMAGE_FN);
    assert(error == 0);
    assert(gMapWidth % ALBEDO_TILE_SIZE == 0);
    assert(gMapHeight % ALBEDO_TILE_SIZE == 0);
#endif

#if WRITE_ELEVATION_FILES
    printf("Loading elevation...\n");
    unsigned int elevationWidth = 0;
    unsigned int elevationHeight = 0;
    error = lodepng_decode32_file(&gElevationMap, &elevationWidth, &elevationHeight, ELEVATION_BASE_IMAGE_FN);
    assert(error == 0);

#if WRITE_ALBEDO_FILES
    assert(elevationWidth == gMapWidth);
    assert(elevationHeight == gMapHeight);
#else
    gMapWidth = elevationWidth;
    gMapHeight = elevationHeight;
#endif

    gElevationMapF = (float*)gElevationMap;

    printf("Converting elevation map to float...\n");

    // Convert from u8 to f32
    for (unsigned int i = 0; i < gMapWidth*gMapHeight; ++i)
        gElevationMapF[i] = ((float)gElevationMap[i * 4 + 3] * (float)gElevationMap[i * 4 + 2]) / 255.0f;

    assert(ELEVATION_TILE_SIZE <= ALBEDO_TILE_SIZE);

    // Already downscale our elevation map
    int w = gMapWidth;
    int h = gMapHeight;
    for (int i = ALBEDO_TILE_SIZE; i > ELEVATION_TILE_SIZE; i /= 2)
    {
        halfF(gElevationMapF, w, h);
        w /= 2;
        h /= 2;
    }
#endif

    gMapSize = Vec2((float)gMapWidth, (float)gMapHeight);

    printf("Loaded %dx%d albedo and elevation maps.\n", gMapWidth, gMapHeight);


#if ENABLE_RENDER_SHADOWS
    printf("Rendering shadows...\n");

    {
        ShadowRendererParams rendererParams[NUM_SHADOW_RENDERER_THREADS];
        HANDLE threadHandles[NUM_SHADOW_RENDERER_THREADS];

        for (int i = 0; i < NUM_SHADOW_RENDERER_THREADS; ++i)
        {
            rendererParams[i].startY = i * (gMapHeight / NUM_SHADOW_RENDERER_THREADS);
            rendererParams[i].endY = rendererParams[i].startY + (gMapHeight / NUM_SHADOW_RENDERER_THREADS) - 1;
        }

        for (int i = 0; i < NUM_SHADOW_RENDERER_THREADS; ++i)
        {
            threadHandles[i] =
                CreateThread(
                    NULL,                           // default security attributes
                    0,                              // use default stack size  
                    ShadowThreadFunction,           // thread function name
                    &rendererParams[i],             // argument to thread function 
                    0,                              // use default creation flags 
                    &rendererParams[i].threadID);   // returns the thread identifier 

            assert(threadHandles[i] != NULL);
        }

        WaitForMultipleObjects(NUM_SHADOW_RENDERER_THREADS, threadHandles, TRUE, INFINITE);

        for (int i = 0; i<NUM_SHADOW_RENDERER_THREADS; i++)
            CloseHandle(threadHandles[i]);
    }
#endif


#if ENABLE_RENDER_BORDERGRADIENT
    printf("Rendering border gradient.\n");

    for (int y = 0; y < (int)gMapHeight; y++)
    {
        // dist to y=255 and y=h-255
        float yd = max(0, abs(y - (int)gMapHeight / 2) - (((int)gMapHeight / 2) - 255)) / 255.0f;
        float yd2 = yd * yd;

        for (int x = 0; x < (int)gMapWidth; ++x)
        {
            float xd = max(0, abs(x - (int)gMapWidth / 2) - (((int)gMapWidth / 2) - 255)) / 255.0f;

            float distFromEdge = sqrtf(xd*xd + yd2);
            float intensity = 1.0f - min(distFromEdge, 1.0f);

            gAlbedoMap[(x + y * gMapWidth) * 4]     = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4] * intensity);
            gAlbedoMap[(x + y * gMapWidth) * 4 + 1] = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4 + 1] * intensity);
            gAlbedoMap[(x + y * gMapWidth) * 4 + 2] = (unsigned char)(gAlbedoMap[(x + y * gMapWidth) * 4 + 2] * intensity);
        }
    }
#endif


#if WRITE_ELEVATION_FILES
    if (ELEVATION_MAP_PIXELOFFSET_Y != 0 || ELEVATION_MAP_PIXELOFFSET_X != 0)
    {
        printf("Moving elevation map a little (to fix alignment)...\n");

        for (int ty = (int)gMapHeight - 1; ty >= 0; --ty)
        {
            int tty = max(0, ty - ELEVATION_MAP_PIXELOFFSET_Y);

            for (int tx = (int)gMapWidth - 1; tx >= 0; --tx)
            {
                int ttx = max(0, tx - ELEVATION_MAP_PIXELOFFSET_X);

                gElevationMapF[tx + (ty*gMapWidth)] = gElevationMapF[ttx + (tty*gMapWidth)];
            }
        }
    }
#endif

#if WRITE_ALBEDO_FILES || WRITE_ELEVATION_FILES

    printf("Saving tiles.\n");

    unsigned char* tempColBuffer = new unsigned char[ALBEDO_TILE_SIZE*ALBEDO_TILE_SIZE * 4];
    Vertex* tempVertexBuffer = new Vertex[(ELEVATION_TILE_SIZE+1)*(ELEVATION_TILE_SIZE+1)];

    CreateDirectoryA(OUTPUT_BASE_PATH, NULL);

    int albedoMapWidth = gMapWidth;
    int albedoMapHeight = gMapHeight;
    int elevationMapWidth = gMapWidth / (ALBEDO_TILE_SIZE / ELEVATION_TILE_SIZE);
    int elevationMapHeight = gMapHeight / (ALBEDO_TILE_SIZE / ELEVATION_TILE_SIZE);

    int lod = 0;
    while (true)
    {
        printf("Lod %d...\n", lod);

        char lodpath[512];
        sprintf_s(lodpath, 512, "%s\\%d", OUTPUT_BASE_PATH, lod);
        CreateDirectoryA(lodpath, NULL);

        for (int y = 0; y < albedoMapHeight; y += ALBEDO_TILE_SIZE)
        {
            char path[512];
            sprintf_s(path, 512, "%s\\%d\\%d", OUTPUT_BASE_PATH, lod, y / ALBEDO_TILE_SIZE);
            CreateDirectoryA(path, NULL);

            for (int x = 0; x < albedoMapWidth; x += ALBEDO_TILE_SIZE)
            {
#if WRITE_ALBEDO_FILES
                char fn[512];
                sprintf_s(fn, 512, "%s\\%d.jpg", path, x / ALBEDO_TILE_SIZE);
                printf("Writing %s.\n", fn);
                saveImage24(gAlbedoMap, fn, x, y, min(ALBEDO_TILE_SIZE, albedoMapWidth), min(ALBEDO_TILE_SIZE, albedoMapHeight), albedoMapWidth, albedoMapHeight, tempColBuffer);
#endif

#if WRITE_ELEVATION_FILES
                char fne[512];
                sprintf_s(fne, 512, "%s\\%d.el", path, x / ALBEDO_TILE_SIZE);
                printf("Writing %s.\n", fne);
                int downscalefactor = ALBEDO_TILE_SIZE / ELEVATION_TILE_SIZE;
                saveMesh(gElevationMapF, fne, x / downscalefactor, y / downscalefactor,
                    min(ELEVATION_TILE_SIZE, elevationMapWidth), min(ELEVATION_TILE_SIZE, elevationMapHeight),
                    elevationMapWidth, elevationMapHeight, tempVertexBuffer);
#endif
            }
        }

        if (albedoMapWidth <= ALBEDO_TILE_SIZE && albedoMapHeight <= ALBEDO_TILE_SIZE)
            break;

        // Half our source buffers
#if WRITE_ALBEDO_FILES
        half(gAlbedoMap, albedoMapWidth, albedoMapHeight);
#endif 
#if WRITE_ELEVATION_FILES
        halfF(gElevationMapF, elevationMapWidth, elevationMapHeight);
#endif
        lod++;
        albedoMapWidth /= 2;
        albedoMapHeight /= 2;
        elevationMapWidth /= 2;
        elevationMapHeight /= 2;
    }    

    delete[] tempColBuffer;
    delete[] tempVertexBuffer;


    free(gAlbedoMap);
    free(gElevationMap);

#endif


#if WRITE_ELEVATION_INDICES_FILE
    printf("Saving elevation indices file...\n");

    CreateDirectoryA(OUTPUT_BASE_PATH, NULL);

    {
        char fn[512];
        sprintf_s(fn, 512, "%s\\tile.indices", OUTPUT_BASE_PATH);
        saveMeshIndices(fn, ELEVATION_TILE_SIZE, ELEVATION_TILE_SIZE);
    }
#endif

    return 0;
}

