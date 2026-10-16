#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )

int main() {
    void *virtual_base;
    int fd;
    void *h2p_lw_led_addr;
    uint32_t led_reg = 0;
    uint32_t occupancy = 0;
    int32_t offset = 0;
    int option = 0;

    // Open /dev/mem
    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERROR: cannot open \"/dev/mem\"...\n");
        return 1;
    }

    // Map physical memory
    virtual_base = mmap(NULL, HW_REGS_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, HW_REGS_BASE);

    if (virtual_base == MAP_FAILED) {
        printf("ERROR: mmap() failed...\n");
        close(fd);
        return 1;
    }

    // Calculate the LED PIO address
    h2p_lw_led_addr = virtual_base + ((unsigned long)(ALT_LWFPGASLVS_OFST + LED_PIO_BASE) & (unsigned long)(HW_REGS_MASK));

    // Main interaction loop
    while (1) {
        printf("\n=== MENU ===\n");
        printf("1 - Set occupancy (0 to 127)\n");
        printf("2 - Set offset (-4096 to 4095)\n");
        printf("0 - Exit\n");
        printf("Select an option: ");

        if (scanf("%d", &option) != 1) {
            while (getchar() != '\n');
            printf("Invalid input. Try again.\n");
            continue;
        }

        switch (option) {
            case 1:
                printf("Enter occupancy (0 - 127): ");
                if (scanf("%u", &occupancy) != 1 || occupancy > 127) {
                    while (getchar() != '\n');
                    printf("Invalid occupancy value.\n");
                } else {
                    // Clear bits [7:0] and insert new occupancy
                    led_reg &= ~0xFF;
                    led_reg |= (occupancy & 0x7F);
                    *(uint32_t *)h2p_lw_led_addr = led_reg;
                    printf("Occupancy updated to %u\n", occupancy);
                }
                break;

            case 2:
                printf("Enter offset (-4096 to 4095): ");
                if (scanf("%d", &offset) != 1 || offset < -4096 || offset > 4095) {
                    while (getchar() != '\n');
                    printf("Invalid offset value.\n");
                } else {
                    // Clear bits [19:7]
                    led_reg &= ~(0x1FFF << 7);
                    // Convert offset to 13-bit two's complement and shift to bits [19:7]
                    uint32_t offset_bits = ((uint32_t)(offset & 0x1FFF)) << 7;
                    led_reg |= offset_bits;
                    *(uint32_t *)h2p_lw_led_addr = led_reg;
                    printf("Offset updated to %d\n", offset);
                }
                break;

            case 0:
                printf("Exiting...\n");
                munmap(virtual_base, HW_REGS_SPAN);
                close(fd);
                return 0;

            default:
                printf("Invalid option. Try again.\n");
                break;
        }
    }

    munmap(virtual_base, HW_REGS_SPAN);
    close(fd);
    return 0;
}
