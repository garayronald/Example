attribute vec4 postion;
attribute vec2 texCoordIn;

varying vec2 texCoordOut;
varying vec2 texCoordOut_UV;

uniform mat4 projection;
uniform mat4 modelView;

void main(void) 
{
    gl_Position = position * projection * modelView;
    texCoordOut = texCoordIn;
}