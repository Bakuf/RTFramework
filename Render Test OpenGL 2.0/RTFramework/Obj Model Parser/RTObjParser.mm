//
//  RTObjParser.h
//  Render Test OpenGL 2.0
//
//  Created by Bakuf on 3/28/15.
//  Copyright (c) 2015 Bakuf Soft. All rights reserved.
//

#include "RTObjParser.h"

using namespace std;

Model getOBJinfo(string fp)
{
    Model model = {0};
    
    // Open OBJ file
    ifstream inOBJ;
    inOBJ.open(fp);
    if(!inOBJ.good())
    {
        cout << "ERROR OPENING OBJ FILE" << endl;
        exit(1);
    }
    
    // Read OBJ file
    while(!inOBJ.eof())
    {
        string line;
        getline(inOBJ, line);
        string type = line.substr(0,2);
        
        if(type.compare("v ") == 0)
            model.positions++;
        else if(type.compare("vt") == 0)
            model.texels++;
        else if(type.compare("vn") == 0)
            model.normals++;
        else if(type.compare("f ") == 0)
            model.faces++;
    }
    
    model.vertices = model.faces*3;
    
    // Close OBJ file
    inOBJ.close();
    
    return model;
}

void extractOBJdata(string fp, float positions[][3], float texels[][2], float normals[][3], int faces[][9])
{
    // Counters
    int p = 0;
    int t = 0;
    int n = 0;
    int f = 0;
    
    // Open OBJ file
    ifstream inOBJ;
    inOBJ.open(fp);
    if(!inOBJ.good())
    {
        cout << "ERROR OPENING OBJ FILE" << endl;
        exit(1);
    }
    
    // Read OBJ file
    while(!inOBJ.eof())
    {
        string line;
        getline(inOBJ, line);
        string type = line.substr(0,2);
        
        // Positions
        if(type.compare("v ") == 0)
        {
            // Copy line for parsing
            char* l = new char[line.size()+1];
            memcpy(l, line.c_str(), line.size()+1);
            
            // Extract tokens
            strtok(l, " ");
            for(int i=0; i<3; i++)
                positions[p][i] = atof(strtok(NULL, " "));
            
            // Wrap up
            delete[] l;
            p++;
        }
        
        // Texels
        else if(type.compare("vt") == 0)
        {
            char* l = new char[line.size()+1];
            memcpy(l, line.c_str(), line.size()+1);
            
            strtok(l, " ");
            for(int i=0; i<2; i++)
                texels[t][i] = atof(strtok(NULL, " "));
            
            delete[] l;
            t++;
        }
        
        // Normals
        else if(type.compare("vn") == 0)
        {
            char* l = new char[line.size()+1];
            memcpy(l, line.c_str(), line.size()+1);
            
            strtok(l, " ");
            for(int i=0; i<3; i++)
                normals[n][i] = atof(strtok(NULL, " "));
            
            delete[] l;
            n++;
        }
        
        // Faces
        else if(type.compare("f ") == 0)
        {
            char* l = new char[line.size()+1];
            memcpy(l, line.c_str(), line.size()+1);
            
            strtok(l, " ");
            for(int i=0; i<9; i++)
                faces[f][i] = atof(strtok(NULL, " /"));
            
            delete[] l;
            f++;
        }
    }
    
    // Close OBJ file
    inOBJ.close();
}

void RTObjParser::init( void )
{
    self = new RTObjParser();
}

void RTObjParser::processObjFile(string filepathObj)
{
    // Model Info
    model = getOBJinfo(filepathObj);
    
    // Model Data
    float positions[model.positions][3];    // XYZ
    float texels[model.texels][2];          // UV
    float normals[model.normals][3];        // XYZ
    int faces[model.faces][9];              // PTN PTN PTN
    
    extractOBJdata(filepathObj, positions, texels, normals, faces);
    
    // Positions
    positionData = new float [model.vertices*3];
    int counter = 0;
    for(int i=0; i<model.faces; i++)
    {
        for (int j = 0; j < 3; j++) {
            int VPos = faces[i][j*3]-1;
            for (int k = 0; k<3; k++) {
                positionData[counter] = (float)positions[VPos][k];
                counter++;
            }
        }
    }
    
    // Texels
    textureData = new float [model.vertices*2];
    counter = 0;
    for(int i=0; i<model.faces; i++)
    {
        for (int j = 0; j < 3; j++) {
            int VTex = faces[i][(j*(3))+1]-1;
            for (int k = 0; k<2; k++) {
                textureData[counter] = (float)texels[VTex][k];
                counter++;
            }
        }
    }
    
    // Normals
    normalData = new float [model.vertices*3];
    counter = 0;
    for(int i=0; i<model.faces; i++)
    {
        for (int j = 0; j < 3; j++) {
            int VPos = faces[i][(j*3)+2]-1;
            for (int k = 0; k<3; k++) {
                normalData[counter] = (float)normals[VPos][k];
                counter++;
            }
        }
    }
}

void RTObjParser::printPositionData(){
    printf("positionData[%f]{\n",(float)model.vertices*3);
    for (int i = 0; i<(int)model.vertices*3; i++) {
        if ((i+1)%3 != 0){
            printf("%f,",positionData[i]);
        }else{
            printf("%f\n",positionData[i]);
        }
    }
    printf("}\n");
}

void RTObjParser::printTextureData(){
    printf("textureData[%f]{\n",(float)model.vertices*2);
    for (int i = 0; i<(int)model.vertices*2; i++) {
        if ((i+1)%2 != 0){
            printf("%f,",textureData[i]);
        }else{
            printf("%f\n",textureData[i]);
        }
    }
    printf("}\n");
}

void RTObjParser::printNormalData(){
    printf("normalData[%f]{\n",(float)model.vertices*3);
    for (int i = 0; i<(int)model.vertices*3; i++) {
        if ((i+1)%3 != 0){
            printf("%f,",normalData[i]);
        }else{
            printf("%f\n",normalData[i]);
        }
    }
    printf("}\n");
}




