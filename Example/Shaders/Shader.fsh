//
//  Shader.fsh
//  Example
//
//  Created by Ronald Garay on 8/21/12.
//  Copyright (c) 2012 Ronald Garay. All rights reserved.
//

uniform sampler2D SamplerY;
uniform sampler2D SamplerU;
uniform sampler2D SamplerV;

varying highp vec2 texCoordVarying;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    yuv.x = texture2D(SamplerY, texCoordVarying).r;
    yuv.y = texture2D(SamplerU, texCoordVarying).r;
    yuv.z = texture2D(SamplerV, texCoordVarying).r;
    
    // BT.601, which is the standard for SDTV is provided as a reference
    /*
     rgb = mat3(    1,       1,     1,
     0, -.34413, 1.772,
     1.402, -.71414,     0) * yuv;
     */
    
    // Using BT.709 which is the standard for HDTV
    rgb = mat3(      1,       1,      1,
                     0, -.18732, 1.8556,
               1.57481, -.46813,      0) * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}

