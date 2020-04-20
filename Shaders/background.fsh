
uniform sampler2D texture;
varying lowp vec4 textureVertex;

void main() {
    gl_FragColor = texture2D(texture, textureVertex.xy);
}
