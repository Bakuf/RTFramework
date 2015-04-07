//
//  RTObjParser.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 3/28/15.
//  Copyright (c) 2015 Bakuf Soft. All rights reserved.
//

#ifndef __Render_Test_OpenGL_2_0__RTObjParser__
#define __Render_Test_OpenGL_2_0__RTObjParser__

#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>

// Model Structure
typedef struct Model
{
    int vertices;
    int positions;
    int texels;
    int normals;
    int faces;
}
Model;

class RTObjParser
{
public:
        
    void init( void );
    void processObjFile(std::string filepathObj);
    void processWithNormals(std::string filepathObj, Model model);
    void processWithOutNormals(std::string filepathObj, Model model);
    
    void printPositionData(void);
    void printTextureData(void);
    void printNormalData(void);
    
    BOOL hasNormals();
    
    Model model;
    
    float *positionData;
    float *textureData;
    float *normalData;
private:
    void * self;
};

#endif /* defined(__Render_Test_OpenGL_2_0__RTObjParser__) */
