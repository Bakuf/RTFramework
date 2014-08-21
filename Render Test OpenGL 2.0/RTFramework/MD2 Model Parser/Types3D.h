/*
 Copyright (c) 2009 Ben Hopkins
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
*/

#ifndef TYPES3D_H
#define TYPES3D_H

#import <OpenGLES/ES1/gl.h>

typedef struct _glfloat2d
{
	GLfloat x;
	GLfloat y;
} GLfloat2D;

static inline GLfloat2D GLfloat2DMake( GLfloat x, GLfloat y)
{
	GLfloat2D result;
	result.x = x;
	result.y = y;
	return result;
}

typedef struct _glfloat3d
{
	GLfloat x;
	GLfloat y;
	GLfloat z;
} GLfloat3D;

static inline GLfloat3D GLfloat3DMake( GLfloat x, GLfloat y, GLfloat z)
{
	GLfloat3D result;
	result.x = x;
	result.y = y;
	result.z = z;
	return result;
}

typedef struct _glfloatRGBA
{
	GLfloat red;
	GLfloat green;
	GLfloat blue;
	GLfloat alpha;
} GLfloatRGBA;

static inline GLfloatRGBA GLfloatRGBAMake( GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
	GLfloatRGBA result;
	result.red = red;
	result.green = green;
	result.blue = blue;
	result.alpha = alpha;
	return result;
}

typedef struct _glvertex 
{
	GLfloat3D position;
	GLfloat3D normal;
	GLfloatRGBA color;
	GLfloat2D textureCoords;
} GLVertex;

static inline uint approx_distance( int dx, int dy )
{
	uint min, max;
	
	if ( dx < 0 ) dx = -dx;
	if ( dy < 0 ) dy = -dy;
	
	if ( dx < dy )
	{
		min = dx;
		max = dy;
	} else {
		min = dy;
		max = dx;
	}
	
	// coefficients equivalent to ( 123/128 * max ) and ( 51/128 * min )
	return ((( max << 8 ) + ( max << 3 ) - ( max << 4 ) - ( max << 1 ) +
			 ( min << 7 ) - ( min << 5 ) + ( min << 3 ) - ( min << 1 )) >> 8 );
} 

static inline float random_scaler()
{
	return (float)(random()%100000) / 100000;
}

#endif
