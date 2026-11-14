#ifndef ATV_FW_1400_H
#define ATV_FW_1400_H
/* Firmware 14.00 helper offsets (not a 13.52 alias). Pinned source:
 * https://github.com/SENeoV/ps4-linux-loader-ps4linux/blob/581438f804f5fc288cf310abad585f93260e4f1d/linux/fw_offsets.h
 *
 * The packaged v25.1 linux.elf has the generic kernel_main code but its
 * internal firmware lookup table predates FW 14.00. The Android TV runner
 * supplies the actual v25.2 fw_offsets_t layout only for exactly FW 14.00.
 * Do not use this for FW 14.02: its kernel patch sites can be different.
 */
struct atv_fw_offsets {
 unsigned short fw_ver;
 unsigned short padding16;
 unsigned int padding32;
 unsigned long long xfast_syscall, printf_off, kmem_alloc;
 unsigned long long kernel_map, patch1, patch2, pstate;
};
_Static_assert(sizeof(struct atv_fw_offsets)==64,"fw_offsets_t ABI");
_Static_assert(__builtin_offsetof(struct atv_fw_offsets,xfast_syscall)==8,"fw_offsets_t alignment");
_Static_assert(__builtin_offsetof(struct atv_fw_offsets,patch1)==40,"fw_offsets_t patch layout");
static const struct atv_fw_offsets atv_fw_1400 = {
 1400, 0, 0,
 0x1C0ULL, 0x2E07C0ULL, 0x466540ULL, 0x22D1D50ULL, 0x46660CULL, 0x466614ULL, 0x3A2E40ULL
};
#endif
