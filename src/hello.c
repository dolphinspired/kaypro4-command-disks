#include <stdio.h>
#include <string.h>

int main(void) {
    char name[32];
    printf("Enter your name: ");
    fgets(name, sizeof(name), stdin);
    name[strcspn(name, "\r\n")] = '\0';
    printf("Hello, %s!\n", name);
    return 0;
}
