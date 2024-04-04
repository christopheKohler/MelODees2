// MusicDiskBinary.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <optional>
#include <format>
#include <fstream>
#include <ranges>
#include <string_view>
#include <iomanip>
#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <iterator>

#include "lodepng/lodepng.h"
#include "color.h"

struct sMotion
{
    int positiony;
    std::vector<int> motionx;
    std::vector<int> motiony;
};

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
struct sImage
{
    // From PNG
    unsigned char* image;        // RGBA loaded from PNG
    unsigned width, height;      // From PNG
    // From Computation
    std::vector<color> palette;  // This is filled manually (to allow various variations)
    unsigned char* imageindexed; // Using "palette", computed manually
};

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
std::optional<sImage> loadpng(std::string filename, bool isoptionnal = false )
{
    sImage result;
    unsigned error;
    error = lodepng_decode32_file(&(result.image), &(result.width), &(result.height), filename.c_str() );

    if (error==78)
    {
        if (!isoptionnal)
         std::cout << "ERROR FILE NOT FOUND (lodepng_decode32_file) File " << filename.c_str() << "\n";
    }
    else if (error==77)
    {
        std::cout << "ERROR lodepng_decode32_file ERROR WHILE READING\n";
    }
    else if (error==0)
        std::cout << "Picture open " << filename.c_str() << "\n";
    if (error != 0)
        return {}; // Return error code
    else
        return result;
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
template <typename Out>
void splitintoint(const std::string &s, char delim, Out& result) 
{
    std::istringstream iss(s);
    std::string item;
    while (std::getline(iss, item, delim)) {
        result.push_back(stoi(item));
    }
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
std::optional<sMotion> loadmotion(std::string filename)
{
    sMotion result;
    std::fstream newfile;
    newfile.open(filename,std::ios::in); //open a file to perform read operation using file object
    if ( newfile.is_open() ) //checking whether the file is open
    { 
        std::string line1;
        std::getline(newfile, line1);
        std::getline(newfile, line1);
        result.positiony = stoi(line1);
        std::string line2;
        std::getline(newfile, line2);
        std::getline(newfile, line2);
        splitintoint(line2, ',', result.motionx);
        std::string line3;
        std::getline(newfile, line3);
        std::getline(newfile, line3);
        splitintoint(line3, ',', result.motiony);

        newfile.close(); //close the file object.
    }
    else
    {
        return {}; // Return error code
    }

    return result;
}



// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
int FindBestColorAndReturnIndex(color inputcolor, std::vector<color>& allcolors)
{
    int minerror = 99999999;
    int bestindex = 0;
    for (int i = 0; i < allcolors.size(); i++)
    {
        int error = inputcolor.getdiff(allcolors[i]);
        if (error < minerror)
        {
            bestindex = i;
            minerror = error;
        }
    }
    return bestindex;
}

// ---------------------------------------------------------------------
void CreatePictureIndexed(sImage& Image)
{
    // Read pixels and convert to index of palette.
    int nbtotalpixels = Image.width * Image.height;
    auto destindex = new unsigned char[nbtotalpixels]; // Allocated index
    Image.imageindexed = destindex;

    auto palette = Image.palette;

    unsigned char* srcpixels = Image.image;
    for (int i = 0; i < nbtotalpixels; i++)
    {
        //printf("%08x %08x %08x %08x\n", srcpixels[0], srcpixels[1], srcpixels[2], srcpixels[3]);
        color currentcolor{ srcpixels[0], srcpixels[1], srcpixels[2] };
        int index = FindBestColorAndReturnIndex(currentcolor, palette);
        destindex[i] = index;
        //printf("%08x %08x %08x best index %d\n", srcpixels[0], srcpixels[1], srcpixels[2], index);
        srcpixels += 4;
    }
}

// -------------------------------------------------------------------------------
// Source = index. 0 to 32
// Dest, lines side by side (line first plan, first line second plan, and so on).
// destsize have blank at end to align with 16 pixels
void ConvertBufferTo8bits(int numberofelements, int destsize, int nbplans, std::unique_ptr<unsigned char[]>& source, std::unique_ptr<unsigned char[]>& dest)
{
    int numberofbytes = (numberofelements + 7) / 8; // Source, number of bytes to process. Pack of 8 pixels
    int numberofbytesdest = (destsize + 7) / 8;
    int i;

    if (nbplans == 1)
    {
        for (i = 0; i < numberofbytes; i++)
        {
            unsigned char valueout = 0;
            int index = i * 8;
            if (source[index + 0] != 0)
                valueout |= (1 << 7);
            if (source[index + 1] != 0)
                valueout |= (1 << 6);
            if (source[index + 2] != 0)
                valueout |= (1 << 5);
            if (source[index + 3] != 0)
                valueout |= (1 << 4);
            if (source[index + 4] != 0)
                valueout |= (1 << 3);
            if (source[index + 5] != 0)
                valueout |= (1 << 2);
            if (source[index + 6] != 0)
                valueout |= (1 << 1);
            if (source[index + 7] != 0)
                valueout |= (1 << 0);
            // Save output
            dest[i] = valueout;
        }
    }
    else if (nbplans == 2)
    {
        for (i = 0; i < numberofbytes; i++) // Pack of 8 pixels
        {
            unsigned char valueout1 = 0; // 1 byte = 8 pixels
            unsigned char valueout2 = 0;

            int index = i * 8;

            // Analyse 8 pixels
            // Plane 1
            if (source[index + 0] & 0x01)
                valueout1 |= (1 << 7);
            if (source[index + 1] & 0x01)
                valueout1 |= (1 << 6);
            if (source[index + 2] & 0x01)
                valueout1 |= (1 << 5);
            if (source[index + 3] & 0x01)
                valueout1 |= (1 << 4);
            if (source[index + 4] & 0x01)
                valueout1 |= (1 << 3);
            if (source[index + 5] & 0x01)
                valueout1 |= (1 << 2);
            if (source[index + 6] & 0x01)
                valueout1 |= (1 << 1);
            if (source[index + 7] & 0x01)
                valueout1 |= (1 << 0);

            // Plane 2
            if (source[index + 0] & 0x02)
                valueout2 |= (1 << 7);
            if (source[index + 1] & 0x02)
                valueout2 |= (1 << 6);
            if (source[index + 2] & 0x02)
                valueout2 |= (1 << 5);
            if (source[index + 3] & 0x02)
                valueout2 |= (1 << 4);
            if (source[index + 4] & 0x02)
                valueout2 |= (1 << 3);
            if (source[index + 5] & 0x02)
                valueout2 |= (1 << 2);
            if (source[index + 6] & 0x02)
                valueout2 |= (1 << 1);
            if (source[index + 7] & 0x02)
                valueout2 |= (1 << 0);

            // Save output
            dest[i] = valueout1;
            dest[i + numberofbytesdest] = valueout2;
        }
    }
    else if (nbplans == 3)
    {
        for (i = 0; i < numberofbytes; i++) // Pack of 8 pixels
        {
            unsigned char valueout1 = 0; // 1 byte = 8 pixels
            unsigned char valueout2 = 0;
            unsigned char valueout3 = 0;

            int index = i * 8;

            // Analyse 8 pixels
            // Plane 1
            if (source[index + 0] & 0x01)
                valueout1 |= (1 << 7);
            if (source[index + 1] & 0x01)
                valueout1 |= (1 << 6);
            if (source[index + 2] & 0x01)
                valueout1 |= (1 << 5);
            if (source[index + 3] & 0x01)
                valueout1 |= (1 << 4);
            if (source[index + 4] & 0x01)
                valueout1 |= (1 << 3);
            if (source[index + 5] & 0x01)
                valueout1 |= (1 << 2);
            if (source[index + 6] & 0x01)
                valueout1 |= (1 << 1);
            if (source[index + 7] & 0x01)
                valueout1 |= (1 << 0);

            // Plane 2
            if (source[index + 0] & 0x02)
                valueout2 |= (1 << 7);
            if (source[index + 1] & 0x02)
                valueout2 |= (1 << 6);
            if (source[index + 2] & 0x02)
                valueout2 |= (1 << 5);
            if (source[index + 3] & 0x02)
                valueout2 |= (1 << 4);
            if (source[index + 4] & 0x02)
                valueout2 |= (1 << 3);
            if (source[index + 5] & 0x02)
                valueout2 |= (1 << 2);
            if (source[index + 6] & 0x02)
                valueout2 |= (1 << 1);
            if (source[index + 7] & 0x02)
                valueout2 |= (1 << 0);

            // Plane 3
            if (source[index + 0] & 0x04)
                valueout3 |= (1 << 7);
            if (source[index + 1] & 0x04)
                valueout3 |= (1 << 6);
            if (source[index + 2] & 0x04)
                valueout3 |= (1 << 5);
            if (source[index + 3] & 0x04)
                valueout3 |= (1 << 4);
            if (source[index + 4] & 0x04)
                valueout3 |= (1 << 3);
            if (source[index + 5] & 0x04)
                valueout3 |= (1 << 2);
            if (source[index + 6] & 0x04)
                valueout3 |= (1 << 1);
            if (source[index + 7] & 0x04)
                valueout3 |= (1 << 0);

            // Save output
            dest[i] = valueout1;
            dest[i + numberofbytesdest] = valueout2;
            dest[i + numberofbytesdest * 2] = valueout3;
        }

    }
    else if (nbplans == 4)
    {
        for (i = 0; i < numberofbytes; i++) // Pack of 8 pixels
        {
            unsigned char valueout1 = 0; // 1 byte = 8 pixels
            unsigned char valueout2 = 0;
            unsigned char valueout3 = 0;
            unsigned char valueout4 = 0;

            int index = i * 8;

            // Analyse 8 pixels
            // Plane 1
            if (source[index + 0] & 0x01)
                valueout1 |= (1 << 7);
            if (source[index + 1] & 0x01)
                valueout1 |= (1 << 6);
            if (source[index + 2] & 0x01)
                valueout1 |= (1 << 5);
            if (source[index + 3] & 0x01)
                valueout1 |= (1 << 4);
            if (source[index + 4] & 0x01)
                valueout1 |= (1 << 3);
            if (source[index + 5] & 0x01)
                valueout1 |= (1 << 2);
            if (source[index + 6] & 0x01)
                valueout1 |= (1 << 1);
            if (source[index + 7] & 0x01)
                valueout1 |= (1 << 0);

            // Plane 2
            if (source[index + 0] & 0x02)
                valueout2 |= (1 << 7);
            if (source[index + 1] & 0x02)
                valueout2 |= (1 << 6);
            if (source[index + 2] & 0x02)
                valueout2 |= (1 << 5);
            if (source[index + 3] & 0x02)
                valueout2 |= (1 << 4);
            if (source[index + 4] & 0x02)
                valueout2 |= (1 << 3);
            if (source[index + 5] & 0x02)
                valueout2 |= (1 << 2);
            if (source[index + 6] & 0x02)
                valueout2 |= (1 << 1);
            if (source[index + 7] & 0x02)
                valueout2 |= (1 << 0);

            // Plane 3
            if (source[index + 0] & 0x04)
                valueout3 |= (1 << 7);
            if (source[index + 1] & 0x04)
                valueout3 |= (1 << 6);
            if (source[index + 2] & 0x04)
                valueout3 |= (1 << 5);
            if (source[index + 3] & 0x04)
                valueout3 |= (1 << 4);
            if (source[index + 4] & 0x04)
                valueout3 |= (1 << 3);
            if (source[index + 5] & 0x04)
                valueout3 |= (1 << 2);
            if (source[index + 6] & 0x04)
                valueout3 |= (1 << 1);
            if (source[index + 7] & 0x04)
                valueout3 |= (1 << 0);

            // Plane 4
            if (source[index + 0] & 0x08)
                valueout4 |= (1 << 7);
            if (source[index + 1] & 0x08)
                valueout4 |= (1 << 6);
            if (source[index + 2] & 0x08)
                valueout4 |= (1 << 5);
            if (source[index + 3] & 0x08)
                valueout4 |= (1 << 4);
            if (source[index + 4] & 0x08)
                valueout4 |= (1 << 3);
            if (source[index + 5] & 0x08)
                valueout4 |= (1 << 2);
            if (source[index + 6] & 0x08)
                valueout4 |= (1 << 1);
            if (source[index + 7] & 0x08)
                valueout4 |= (1 << 0);

            // Save output
            dest[i] = valueout1;
            dest[i + numberofbytesdest] = valueout2;
            dest[i + numberofbytesdest * 2] = valueout3;
            dest[i + numberofbytesdest * 3] = valueout4;
        }

    }
    else if (nbplans == 5)
    {
        for (i = 0; i < numberofbytes; i++) // Pack of 8 pixels
        {
            unsigned char valueout1 = 0; // 1 byte = 8 pixels
            unsigned char valueout2 = 0;
            unsigned char valueout3 = 0;
            unsigned char valueout4 = 0;
            unsigned char valueout5 = 0;

            int index = i * 8;

            // Analyse 8 pixels
            // Plane 1
            if (source[index + 0] & 0x01)
                valueout1 |= (1 << 7);
            if (source[index + 1] & 0x01)
                valueout1 |= (1 << 6);
            if (source[index + 2] & 0x01)
                valueout1 |= (1 << 5);
            if (source[index + 3] & 0x01)
                valueout1 |= (1 << 4);
            if (source[index + 4] & 0x01)
                valueout1 |= (1 << 3);
            if (source[index + 5] & 0x01)
                valueout1 |= (1 << 2);
            if (source[index + 6] & 0x01)
                valueout1 |= (1 << 1);
            if (source[index + 7] & 0x01)
                valueout1 |= (1 << 0);

            // Plane 2
            if (source[index + 0] & 0x02)
                valueout2 |= (1 << 7);
            if (source[index + 1] & 0x02)
                valueout2 |= (1 << 6);
            if (source[index + 2] & 0x02)
                valueout2 |= (1 << 5);
            if (source[index + 3] & 0x02)
                valueout2 |= (1 << 4);
            if (source[index + 4] & 0x02)
                valueout2 |= (1 << 3);
            if (source[index + 5] & 0x02)
                valueout2 |= (1 << 2);
            if (source[index + 6] & 0x02)
                valueout2 |= (1 << 1);
            if (source[index + 7] & 0x02)
                valueout2 |= (1 << 0);

            // Plane 3
            if (source[index + 0] & 0x04)
                valueout3 |= (1 << 7);
            if (source[index + 1] & 0x04)
                valueout3 |= (1 << 6);
            if (source[index + 2] & 0x04)
                valueout3 |= (1 << 5);
            if (source[index + 3] & 0x04)
                valueout3 |= (1 << 4);
            if (source[index + 4] & 0x04)
                valueout3 |= (1 << 3);
            if (source[index + 5] & 0x04)
                valueout3 |= (1 << 2);
            if (source[index + 6] & 0x04)
                valueout3 |= (1 << 1);
            if (source[index + 7] & 0x04)
                valueout3 |= (1 << 0);

            // Plane 4
            if (source[index + 0] & 0x08)
                valueout4 |= (1 << 7);
            if (source[index + 1] & 0x08)
                valueout4 |= (1 << 6);
            if (source[index + 2] & 0x08)
                valueout4 |= (1 << 5);
            if (source[index + 3] & 0x08)
                valueout4 |= (1 << 4);
            if (source[index + 4] & 0x08)
                valueout4 |= (1 << 3);
            if (source[index + 5] & 0x08)
                valueout4 |= (1 << 2);
            if (source[index + 6] & 0x08)
                valueout4 |= (1 << 1);
            if (source[index + 7] & 0x08)
                valueout4 |= (1 << 0);

            // Plane 5
            if (source[index + 0] & 0x10)
                valueout5 |= (1 << 7);
            if (source[index + 1] & 0x10)
                valueout5 |= (1 << 6);
            if (source[index + 2] & 0x10)
                valueout5 |= (1 << 5);
            if (source[index + 3] & 0x10)
                valueout5 |= (1 << 4);
            if (source[index + 4] & 0x10)
                valueout5 |= (1 << 3);
            if (source[index + 5] & 0x10)
                valueout5 |= (1 << 2);
            if (source[index + 6] & 0x10)
                valueout5 |= (1 << 1);
            if (source[index + 7] & 0x10)
                valueout5 |= (1 << 0);

            // Save output
            dest[i] = valueout1;
            dest[i + numberofbytesdest] = valueout2;
            dest[i + numberofbytesdest * 2] = valueout3;
            dest[i + numberofbytesdest * 3] = valueout4;
            dest[i + numberofbytesdest * 4] = valueout5;
        }

    }
    else
    {
        printf("ConvertBufferTo8bits not coded for planes number %d\n", nbplans);
    }
}


// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
std::vector<color> readpalette(std::string filename)
{
    int r, g, b;
    std::vector<color> allcolors;

    bool ispal=false;
    bool isact=false;

    size_t posdot = filename.find_last_of('.');
    if (posdot != std::string::npos && filename.compare(posdot, 4, ".pal") == 0)
        ispal = true;
    else if (posdot != std::string::npos && filename.compare(posdot, 4, ".act") == 0)
        isact = true;

    if (!ispal && !isact)
    {
        std::cout << "Error. Pal file should be .pal or .act (" << filename << ")" << std::endl;
        exit(1);
    }

    if (ispal)
    {
        std::ifstream input_file(filename);
        if (!input_file.is_open()) 
        {
            std::cout << "Could not open the file - '" << filename << "'" << std::endl;
            exit(1);
        }
        do
        {
            r = -1;

            input_file >> r >> g >> b;
            if (r != -1)
            {
                //printf("Color read %d %d %d\n", r, g, b);
                color palcolor{ r,g,b };
                palcolor.convertto16bits(); // 16 bits compliants.
                allcolors.push_back(palcolor);
            }
        } while (r != -1 && allcolors.size() < 16);
    }

    if (isact)
    {
        // Open binary file. RGB (8 bits)
        std::ifstream palfile(filename, std::ios_base::binary);
        if (!palfile.is_open()) 
        {
            std::cout << "Could not open the file - '" << filename << "'" << std::endl;
            exit(1);
        }
        while (!palfile.eof() && allcolors.size() < 32)
        {
            unsigned char red, green, blue;
            palfile.read((char*) &red, 1);
            palfile.read((char*) &green, 1);
            palfile.read((char*) &blue, 1);
            color palcolor{ red,green,blue };
            palcolor.convertto16bits();
            allcolors.push_back(palcolor);
        }
        palfile.close();
    }
    std::cout << "Palette open " << filename.c_str() << "\n";
    return allcolors;
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
[[nodiscard]] int findnumberofalternative(std::string filename)
{
	int result = 0;
	bool ok=true;
	do
	{
        result++; // Start at 1
        std::string altname;
        altname = filename; // Copy original name
        size_t foundpos = altname.find_last_of('.');
        if (foundpos != std::string::npos)
        {
            std::string altstring = std::format("_alt{}", result);
            altname.insert(foundpos,altstring);
            //std::cout << altname << std::endl;
            // Test if file exist
            std::ifstream f(altname.c_str());
            if (!f.good())
                ok = false; // exit loop
            else
                std::cout << altname << std::endl;
        }
	} while (ok);
	return result-1; // Return number of variations found. 0 to xxx
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void WritePlanesToStream(std::ofstream& outputfile, sImage& Image)
{
    // Write planes "side by side".
    // We can process each line.
    int height = Image.height;
    int widthinpixels = Image.width;
    int widthinbytes = widthinpixels / 8;
    int nbplans = 1;
    if (Image.palette.size() <= 2) nbplans = 1;
    else if (Image.palette.size() <= 4) nbplans = 2;
    else if (Image.palette.size() <= 8) nbplans = 3;
    else if (Image.palette.size() <= 16) nbplans = 4;
    else if (Image.palette.size() <= 32) nbplans = 5;

    std::unique_ptr<unsigned char[]> BytesPlanes = std::make_unique<unsigned char[]>( widthinbytes * nbplans );
    std::unique_ptr<unsigned char[]> PixelsLine = std::make_unique<unsigned char[]>( widthinpixels );

    // -- For all lines
    for (int line = 0; line < height; line++)
    {
        for (int j = 0; j < widthinpixels; j++)
            PixelsLine[j] = 0;

        // Convert pixels to index and then copy to line
        unsigned char* pPixelIndex = Image.imageindexed + (line * widthinpixels);

        for (int j = 0; j < widthinpixels; j++)
        {
            PixelsLine[j] = pPixelIndex[j];
        }

        // Now convert char to bits.
        ConvertBufferTo8bits(widthinpixels, widthinpixels, nbplans, PixelsLine, BytesPlanes);

        // Write bytes
        outputfile.write( reinterpret_cast<const char*>(BytesPlanes.get()),  widthinbytes * nbplans);

    } // All lines

}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void WriteOne16cSpriteToStream(std::ofstream& outputfile, sImage& Image, int offset)
{
    // Write sprites, combined sprite.
    int height = Image.height;
    int widthinpixels = Image.width; // 32
    int widthinbytes = widthinpixels / 8;

    unsigned int encoded[142][4]; // 4 words. Low to higher bits. 142 is max lines

    // -- Sprites (2) (pixels offset to offset + 16)
    for (int line = 0; line < height; line++)
    {
        // Convert pixels to index and then copy to line
        unsigned char* pPixelIndex = Image.imageindexed + (line * widthinpixels) + offset;

        encoded[line][0] = 0;
        encoded[line][1] = 0;
        encoded[line][2] = 0;
        encoded[line][3] = 0;

        int bit = 15;
        for (int j = 0; j < 16; j++)
        {
            int index = pPixelIndex[j];
            
            if (index & 0x01)
                encoded[line][0] |= (0x01 << bit);
            if (index & 0x02)
                encoded[line][1] |= (0x01 << bit);
            if (index & 0x04)
                encoded[line][2] |= (0x01 << bit);
            if (index & 0x08)
                encoded[line][3] |= (0x01 << bit);

            bit--;
        }
    } // All lines


    // Write bytes
    for (int line = 0; line < height; line++)
    {
        unsigned char byte;
        byte = encoded[line][0] >> 8;
        outputfile.write( (const char*) &byte, 1 );
        byte = encoded[line][0] & 0x00ff;
        outputfile.write( (const char*) &byte, 1 );
        // Second part
        byte = encoded[line][1] >> 8;
        outputfile.write( (const char*) &byte, 1 );
        byte = encoded[line][1] & 0x00ff;
        outputfile.write( (const char*) &byte, 1 );
    }
    for (int line = 0; line < height; line++)
    {
        unsigned char byte;
        byte = encoded[line][2] >> 8;
        outputfile.write( (const char*) &byte, 1 );
        byte = encoded[line][2] & 0x00ff;
        outputfile.write( (const char*) &byte, 1 );
        // Second part
        byte = encoded[line][3] >> 8;
        outputfile.write( (const char*) &byte, 1 );
        byte = encoded[line][3] & 0x00ff;
        outputfile.write( (const char*) &byte, 1 );
    }

}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void WriteSpritesToStream(std::ofstream& outputfile, sImage& Image)
{
    unsigned int height = Image.height;
    outputfile.write( (const char*) &height, 2 );
    WriteOne16cSpriteToStream(outputfile, Image, 0);  // Sprite 1 and 2
    WriteOne16cSpriteToStream(outputfile, Image, 16); // Sprite 3 and 4
    WriteOne16cSpriteToStream(outputfile, Image, 32); // Sprite 5 and 6
    WriteOne16cSpriteToStream(outputfile, Image, 48); // Sprite 7 and 8
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void CreateAndSaveMask(std::ofstream& outputfile, sImage& Image)
{
    // Create inverted mask. 1 bitplane. 640x43
    sImage ImageMask;
    // Create Two dummy colors, just to say we are using 1 bitplan
    ImageMask.palette.push_back(color(0, 0, 0));
    ImageMask.palette.push_back(color(255, 255, 255));
    // Allocate indexed bytes
    ImageMask.imageindexed = new unsigned char[640 * 43];
    ImageMask.width = 640;
    ImageMask.height = 43;

    // Convert 640x43 first colors.
    // We invert, so index0 become 1, and inverse.
    for (int i = 0; i < 640 * 43; i++)
    {
        if (Image.imageindexed[i] == 0) ImageMask.imageindexed[i] = 1; // Baclground
        else ImageMask.imageindexed[i] = 0; // Solid color
    }

    WritePlanesToStream(outputfile, ImageMask);

    delete[] ImageMask.imageindexed;
}


// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void ConvertAndSaveSprite(std::ofstream& fileout, sImage& picturesprite,std::vector<color> mainpalette)
{
    picturesprite.palette.push_back(mainpalette[0]); // Transparency
    for (int i=1 ; i<16;i++)
        picturesprite.palette.push_back(mainpalette[16+i]);
    CreatePictureIndexed(picturesprite);
    WriteSpritesToStream(fileout,picturesprite); // 640x93_16c = 29760 bytes
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
void processlevel(int levelid)
{
    std::cout << "Open files of level " << levelid << " ------------------------------------ \n";

    // -- Read Palette
    //01_palette.act (with alt)
    std::string filenamepalette=std::format("0{}_palette.act",levelid);
    std::vector<color> mainpalette = readpalette(filenamepalette);

    std::string filenamepalette1=std::format("0{}_palette_alt1.act",levelid);
    std::vector<color> palette1 = readpalette(filenamepalette1);

    // -- Read images ------------------------------------------------
    //01_paralax_back_320x62_32c.png
    std::string filenameparalaxback=std::format("0{}_paralax_back_320x62_32c.png",levelid);
    std::optional<sImage> pictureparalaxback = loadpng(filenameparalaxback);

    //01_paralax_front_640x93_16c.png
    std::string filenameparalaxfront=std::format("0{}_paralax_front_640x93_16c.png",levelid);
    std::optional<sImage> pictureparalaxfront = loadpng(filenameparalaxfront);

    //01_sky_gradient_64.png (with alt)
    std::string filenamegradientback=std::format("0{}_sky_gradient_64.png",levelid);
    std::optional<sImage> picturegradientback = loadpng(filenamegradientback);

    std::string filenamegradientback1=std::format("0{}_sky_gradient_64_alt1.png",levelid);
    std::optional<sImage> picturegradientback1 = loadpng(filenamegradientback1);

    //01_sprite_16c.png (with alt)
    std::string filenamesprite=std::format("0{}_sprite_16c.png",levelid);
    std::optional<sImage> picturesprite = loadpng(filenamesprite);
    std::string filenamesprite1=std::format("0{}_sprite_16c_alt1.png",levelid);
    std::optional<sImage> picturesprite1 = loadpng(filenamesprite1,true);
    std::string filenamesprite2=std::format("0{}_sprite_16c_alt2.png",levelid);
    std::optional<sImage> picturesprite2 = loadpng(filenamesprite2,true);
    std::string filenamesprite3=std::format("0{}_sprite_16c_alt3.png",levelid);
    std::optional<sImage> picturesprite3 = loadpng(filenamesprite3,true);
    std::string filenamesprite4=std::format("0{}_sprite_16c_alt4.png",levelid);
    std::optional<sImage> picturesprite4 = loadpng(filenamesprite4,true);
    std::string filenamesprite5=std::format("0{}_sprite_16c_alt5.png",levelid);
    std::optional<sImage> picturesprite5 = loadpng(filenamesprite5,true);

    // Motion 01_motion.txt
    std::string filenamemotion=std::format("0{}_motion.txt",levelid);
    std::optional<sMotion> motion = loadmotion(filenamemotion);


    std::cout << "Analyse data --------------- \n";

    // ----------------------------------------------------------------
    // Test if we got all.
    if (mainpalette.size() != 32 || palette1.size() != 32 || !picturegradientback || !picturegradientback1 || !pictureparalaxback || !pictureparalaxfront || !picturesprite || !motion )
    {
        std::cout << "ERROR Something is missing, can not process level " << levelid << std::endl;
        if (mainpalette.size() != 32) std::cout << "Main palette not 32 colors : " << mainpalette.size() << std::endl;
        if (palette1.size() != 32) std::cout << "Palette alt1 not 32 colors : " << palette1.size() << std::endl;
        if (!picturegradientback) std::cout << "Missing picturegradientback " << std::endl;
        if (!picturegradientback1) std::cout << "Missing picturegradientback_alt1 " << std::endl;
        if (!pictureparalaxback) std::cout << "Missing pictureparalaxback " << std::endl;
        if (!pictureparalaxfront) std::cout << "Missing pictureparalaxfront " << std::endl;
        if (!picturesprite) std::cout << "Missing picturesprite " << std::endl;
        if (!motion) std::cout << "Missing motion " << std::endl;
        return;
    }
    // Check constaints.
    if (pictureparalaxback->width != 320 || pictureparalaxback->height != 62 )
    {
        std::cout << "ERROR " << filenameparalaxback << " size should be 320x62 (" << pictureparalaxback->width << "x" <<  pictureparalaxback->height << ")" << std::endl;
        return;
    }
    if (pictureparalaxfront->width != 640 || pictureparalaxfront->height != 93 )
    {
        std::cout << "ERROR " << filenameparalaxfront << " size should be 640x93 (" << pictureparalaxfront->width << "x" <<  pictureparalaxfront->height << ")" << std::endl;
        return;
    }
    // Gradient
    if (picturegradientback->height != 64 )
    {
        std::cout << "ERROR " << filenamegradientback << " height should be 64 (" << picturegradientback->height << ")" << std::endl;
        return;
    }
    // Sprite
    if (picturesprite->width != 64 || picturesprite->height > 100 )
    {
        std::cout << "ERROR " << filenamesprite << " width should be 64 and height max is 100 (" << picturesprite->width << "x" <<  picturesprite->height << ")" << std::endl;
        return;
    }
    if (picturesprite1)
    {
        if (picturesprite1->width != 64 || picturesprite1->height != picturesprite->height)
        {
            std::cout << "ERROR " << filenamesprite1 << " width should be 64 and same height as sprite0 (" << picturesprite1->height << "!=" <<  picturesprite->height << ")" << std::endl;
            return;
        }
    }
    if (picturesprite2)
    {
        if (picturesprite2->width != 64 || picturesprite2->height != picturesprite->height)
        {
            std::cout << "ERROR " << filenamesprite2 << " width should be 64 and same height as sprite0 (" << picturesprite2->height << "!=" <<  picturesprite->height << ")" << std::endl;
            return;
        }
    }
    if (picturesprite3)
    {
        if (picturesprite3->width != 64 || picturesprite3->height != picturesprite->height)
        {
            std::cout << "ERROR " << filenamesprite3 << " width should be 64 and same height as sprite0 (" << picturesprite3->height << "!=" <<  picturesprite->height << ")" << std::endl;
            return;
        }
    }
    if (picturesprite4)
    {
        if (picturesprite4->width != 64 || picturesprite4->height != picturesprite->height)
        {
            std::cout << "ERROR " << filenamesprite4 << " width should be 64 and same height as sprite0 (" << picturesprite4->height << "!=" <<  picturesprite->height << ")" << std::endl;
            return;
        }
    }
    if (picturesprite5)
    {
        if (picturesprite5->width != 64 || picturesprite5->height != picturesprite->height)
        {
            std::cout << "ERROR " << filenamesprite5 << " width should be 64 and same height as sprite0 (" << picturesprite5->height << "!=" <<  picturesprite->height << ")" << std::endl;
            return;
        }
    }

    std::cout << "Save Binary --------------- \n";

    // ----------------------------------------------------------------
    // Output file
    //
    // 32c palette
    // Back parallax 32c
    // Front parallax 16c
    // Mask
    // Number of palette pair = x
    //  x palette 32 colors (RGB mode)
    //  x palette background 64 colors (RGB mode)
    // Motion data
    //  posy
    //  number of x
    //   x,x,x,x,x,,x
    //  number of y
    //   y,y,y,y,y,y
    // Sprite data
    //   Num frames
    //   Frames 1
    //   Frames 2
    //   Frames 3
    //   .....
    // ----------------------------------------------

    std::ofstream fileout;
    std::string filenamebinary=std::format("Sources/datas/Level{}.bin",levelid);
    fileout.open(filenamebinary, std::ios::binary | std::ios::out);

    // 1. Write palette (16 bits formats) 32 colors (64 bytes)
    for (auto mycolor : mainpalette)
        mycolor.writetostreamas16bits(fileout);
    // TODO read and write variations

    // 2. Convert and write back paralax // pictureparalaxback 32colors
    pictureparalaxback->palette = mainpalette;
    CreatePictureIndexed(pictureparalaxback.value());
    WritePlanesToStream(fileout,pictureparalaxback.value()); // 320x62x5 = 12400 bytes

    // 3. Convert and write front paralax // paralaxfront 16colors
    for (int i=0 ; i<16;i++)
        pictureparalaxfront->palette.push_back(mainpalette[i]);
    CreatePictureIndexed(pictureparalaxfront.value());
    WritePlanesToStream(fileout,pictureparalaxfront.value()); // 640x93_16c = 29760 bytes

    // 4. Create and save Mask for front // 640x43 lines first 
    CreateAndSaveMask(fileout,pictureparalaxfront.value()); // 3440 bytes

    // 5. Write palette 32 colors (RGB 255)
    for (auto mycolor : mainpalette)
    {
        fileout.write((const char*)&(mycolor.r), 1);
        fileout.write((const char*)&(mycolor.g), 1);
        fileout.write((const char*)&(mycolor.b), 1);
    }
    for (auto mycolor : palette1)
    {
        fileout.write((const char*)&(mycolor.r), 1);
        fileout.write((const char*)&(mycolor.g), 1);
        fileout.write((const char*)&(mycolor.b), 1);
    }

    // 6. Write Background 64 colors (RGB 255)
    {
        unsigned char* pSource = picturegradientback->image;
        int width = picturegradientback->width;
        for (int i = 0; i < 64; i++)
        {
            int index = i * width * 4;
            color currentcolor{ pSource[index+0], pSource[index+1], pSource[index+2] };
            fileout.write((const char*)&(currentcolor.r), 1);
            fileout.write((const char*)&(currentcolor.g), 1);
            fileout.write((const char*)&(currentcolor.b), 1);
        }
    }
    {
        unsigned char* pSource = picturegradientback1->image;
        int width = picturegradientback1->width;
        for (int i = 0; i < 64; i++)
        {
            int index = i * width * 4;
            color currentcolor{ pSource[index+0], pSource[index+1], pSource[index+2] };
            fileout.write((const char*)&(currentcolor.r), 1);
            fileout.write((const char*)&(currentcolor.g), 1);
            fileout.write((const char*)&(currentcolor.b), 1);
        }
    }

    // 7. Write motion
    // TODO

    // 8. Write sprite.
    // 8 sprites, each 16 pixels wide (and they are paired to be 16 colors).
    // Create 16 colors palette
    int nbsprite = 1;
    int dummynul = 0;
    if (picturesprite1) nbsprite++;
    if (picturesprite2) nbsprite++;
    if (picturesprite3) nbsprite++;
    if (picturesprite4) nbsprite++;
    if (picturesprite5) nbsprite++;
    fileout.write((const char*)&(dummynul), 1); // Save a word telling how many sprite there are
    fileout.write((const char*)&(nbsprite), 1);
    // Then saveeach sprite
    if (picturesprite)
        ConvertAndSaveSprite(fileout, picturesprite.value(),mainpalette);
    if (picturesprite1)
        ConvertAndSaveSprite(fileout, picturesprite1.value(),mainpalette);
    if (picturesprite2)
        ConvertAndSaveSprite(fileout, picturesprite2.value(),mainpalette);
    if (picturesprite3)
        ConvertAndSaveSprite(fileout, picturesprite3.value(),mainpalette);
    if (picturesprite4)
        ConvertAndSaveSprite(fileout, picturesprite4.value(),mainpalette);
    if (picturesprite5)
        ConvertAndSaveSprite(fileout, picturesprite5.value(),mainpalette);

    // Dummy value to add padding
    CreateAndSaveMask(fileout, pictureparalaxfront.value()); // 3440 bytes

    fileout.close();

    std::cout << "END -------------------------------------------- \n";
}

// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
int main()
{
    std::cout << "Program Start!\n";

    processlevel(1);
    processlevel(2);
    processlevel(3);
    processlevel(4);
    processlevel(5);
    processlevel(6);
    processlevel(7);
    processlevel(8);
}
