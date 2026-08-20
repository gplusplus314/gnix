uniform mat4 modelViewProjectionMatrix;

in vec2 vertex;
out vec2 v_pixel;

void main()
{
    v_pixel = vertex;
    gl_Position = modelViewProjectionMatrix * vec4(vertex, 0.0, 1.0);
}
