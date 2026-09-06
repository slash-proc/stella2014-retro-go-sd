#include "DefPropsBin.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* Optional STDP trailer after the packed CORE .bin — see
 * scripts/append_stella_defprops.py. When present, the defprops DB lives at
 * an absolute offset inside the same file as the core. */
#define STDP_MAGIC       0x50445453u /* 'S','T','D','P' */
#define STDP_VERSION     1u
#define STDP_FOOTER_SIZE 16u

static FILE* props_file = NULL;
static uint32_t num_entries = 0;
static uint32_t entry_size = 0;
/* Absolute file offset of the defprops header (num_entries / entry_size). */
static long props_base = 0;

static uint32_t rd_u32le(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

// Convert hex string to binary
static bool hex_to_binary(const char* hex, unsigned char* binary, size_t binary_len) {
    if (strlen(hex) != binary_len * 2) {
        return false;
    }

    for (size_t i = 0; i < binary_len; i++) {
        char hex_byte[3] = {hex[i*2], hex[i*2+1], '\0'};
        char* end;
        binary[i] = strtol(hex_byte, &end, 16);
        if (*end != '\0') {
            return false;
        }
    }
    return true;
}

/* If filename ends with an STDP footer, set props_base to the embedded
 * defprops offset. Otherwise leave props_base at 0 (whole file = DB). */
static bool try_stdp_footer(FILE *file)
{
    uint8_t footer[STDP_FOOTER_SIZE];

    if (fseek(file, 0, SEEK_END) != 0)
        return false;
    long filesize = ftell(file);
    if (filesize < (long)STDP_FOOTER_SIZE)
        return false;
    if (fseek(file, filesize - (long)STDP_FOOTER_SIZE, SEEK_SET) != 0)
        return false;
    if (fread(footer, 1, STDP_FOOTER_SIZE, file) != STDP_FOOTER_SIZE)
        return false;

    uint32_t magic = rd_u32le(footer);
    uint32_t version = rd_u32le(footer + 4);
    uint32_t off = rd_u32le(footer + 8);
    uint32_t size = rd_u32le(footer + 12);

    if (magic != STDP_MAGIC || version != STDP_VERSION)
        return false;
    if (size < 8)
        return false;
    if ((uint64_t)off + size > (uint64_t)filesize - STDP_FOOTER_SIZE)
        return false;

    props_base = (long)off;
    return true;
}

bool defprops_init(const char* filename) {
    props_file = fopen(filename, "rb");
    if (!props_file) {
        return false;
    }

    props_base = 0;
    if (!try_stdp_footer(props_file))
        props_base = 0;

    if (fseek(props_file, props_base, SEEK_SET) != 0) {
        fclose(props_file);
        props_file = NULL;
        return false;
    }

    // Read header: number of entries and entry size
    if (fread(&num_entries, sizeof(uint32_t), 1, props_file) != 1 ||
        fread(&entry_size, sizeof(uint32_t), 1, props_file) != 1) {
        fclose(props_file);
        props_file = NULL;
        return false;
    }

    if (num_entries == 0 || entry_size < MD5_LENGTH_BIN) {
        fclose(props_file);
        props_file = NULL;
        return false;
    }

    return true;
}

static bool read_fixed_string(char* dest, size_t max_len, size_t field_len) {
    if (!dest || max_len == 0)
        return false;
    if (fread(dest, 1, field_len, props_file) != field_len) {
        return false;
    }
    /* File fields are fixed-width and zero-padded. dest is typically exactly
     * field_len bytes — never write dest[field_len] (one past the end). */
    if (field_len < max_len)
        dest[field_len] = '\0';
    else
        dest[max_len - 1] = '\0';
    return true;
}

bool defprops_get_properties(const char* md5, rom_properties_t* props) {
    if (!props_file || !md5 || !props) {
        return false;
    }

    // Convert input MD5 string to binary
    unsigned char md5_binary[MD5_LENGTH_BIN];
    if (!hex_to_binary(md5, md5_binary, MD5_LENGTH_BIN)) {
        return false;
    }

    // Binary search for the MD5
    long left = 0;
    long right = (long)num_entries - 1;
    unsigned char current_md5[MD5_LENGTH_BIN];

    while (left <= right) {
        long mid = (left + right) / 2;

        // Calculate position in file (relative to embedded/base defprops)
        long pos = props_base + (long)(sizeof(uint32_t) * 2) + mid * (long)entry_size;
        fseek(props_file, pos, SEEK_SET);
        // Read MD5
        if (fread(current_md5, 1, MD5_LENGTH_BIN, props_file) != MD5_LENGTH_BIN) {
            return false;
        }

        // Compare binary MD5s
        int cmp = memcmp(md5_binary, current_md5, MD5_LENGTH_BIN);
        if (cmp == 0) {
            // Found the entry, read all properties
            fseek(props_file, pos, SEEK_SET);

            // Skip MD5
            fseek(props_file, MD5_LENGTH_BIN, SEEK_CUR);

            // Read all properties
            if (!read_fixed_string(props->mapper, sizeof(props->mapper), MAPPER_LENGTH) ||
                !read_fixed_string(props->difficulty, sizeof(props->difficulty), DIFFICULTY_LENGTH) ||
                !read_fixed_string(props->control_swap, sizeof(props->control_swap), CONTROL_SWAP_LENGTH) ||
                !read_fixed_string(props->control_left, sizeof(props->control_left), CONTROL_LENGTHL) ||
                !read_fixed_string(props->control_right, sizeof(props->control_right), CONTROL_LENGTHR) ||
                !read_fixed_string(props->paddle_swap, sizeof(props->paddle_swap), PADDLE_SWAP_LENGTH) ||
                !read_fixed_string(props->region, sizeof(props->region), REGION_LENGTH) ||
                !read_fixed_string(props->yoffset, sizeof(props->yoffset), YOFFSET_LENGTH) ||
                !read_fixed_string(props->height, sizeof(props->height), HEIGHT_LENGTH)) {
                return false;
            }
            return true;
        }

        if (cmp < 0) {
            right = mid - 1;
        } else {
            left = mid + 1;
        }
    }

    return false;
}

void defprops_cleanup(void) {
    if (props_file) {
        fclose(props_file);
        props_file = NULL;
    }
    props_base = 0;
    num_entries = 0;
    entry_size = 0;
}
