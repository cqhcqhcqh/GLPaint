
attribute vec4 inVertex;
attribute vec4 inTextureVertex;
//uniform mat4 MVP;
varying lowp vec4 textureVertex;

void main()
{
    gl_Position = inVertex;// * MVP;
    textureVertex = inTextureVertex;
}
