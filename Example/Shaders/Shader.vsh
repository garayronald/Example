//
//  Shader.vsh
//  Example
//
//  Created by Ronald Garay on 8/21/12.
//  Copyright (c) 2012 Ronald Garay. All rights reserved.
//

attribute vec4 position;
attribute vec2 texCoord;

varying vec2 texCoordVarying;

void main()
{
    gl_Position = position;
    texCoordVarying = texCoord;
}
