uniform sampler2D sampler_y; // Y Texture
uniform sampler2D sampler_u; // U Texture
uniform sampler2D sampler_v; // V Texture

varying highp vec2 TexCoordOut;

void main()
{
    highp float y = texture2D(sampler_u, TexCoordOut).r;
    highp float u = texture2D(sampler_u, TexCoordOut).r - 0.5;
    highp float v = texture2D(sampler_u, TexCoordOut).r - 0.5;

    //y = 0.0;
    //u = 0.0;
    //v = 0.0;

    highp float r = y + 1.13983 * v;
    highp float g = y - 0.39465 * u - 0.58060 * v;
    highp float b = y + 2.03211 * u;

    gl_FragColor = vec4(r, g, b, 1.0);
}