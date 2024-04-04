
typedef struct
{
  int w, h;
  unsigned char* pix; // 3 components
} image_t, *image;

// Compute best colors for image
void color_quant(image im, int n_colors, unsigned char* result_colors);

int write_ppm(image im, char *name);