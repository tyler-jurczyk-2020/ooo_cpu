
int main() {
    int j = 0;
    int val1 = 0;
    int val2 = 0;
    for(int i = 0; i < 1000; i++) {
        if(i % 2 == 0) {
            val1 = !val1;
            j++;
        }
        if(j % 2 == 0) {
            val2 = !val2;
            i++;
        }
    }
}
