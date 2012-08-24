uniform sampler2D sampler_y;
uniform sampler2D sampler_u;
uniform sampler2D sampler_v;

varying highp vec2 texCoordOut;

void main(void) 
{
    highp float y = texture2D(sampler_y, texCoordVarying).r;
    highp float u = texture2D(sampler_u, texCoordVarying).r - 0.5;
    highp float v = texture2D(sampler_v, texCoordVarying).r - 0.5;

    highp float r = y                 + 1.13983 * v;
    highp float g = y   - 0.39465 * u - 0.58060 * v;
    highp float b = y   + 2.03211 * u;

    gl_FragColor = vec4(r, g, b, 1.0);
}