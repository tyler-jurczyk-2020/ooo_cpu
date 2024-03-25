void swap(int* arr, int i, int j) 
{ 
    int temp = arr[i]; 
    arr[i] = arr[j]; 
    arr[j] = temp; 
} 

void bubbleSort(int arr[], int n) 
{ 
    int i, j; 
    for (i = 0; i < n - 1; i++) 
  
        // Last i elements are already 
        // in place 
        for (j = 0; j < n - i - 1; j++) 
            if (arr[j] > arr[j + 1]) 
                swap(arr, j, j + 1); 
} 

int main() 
{ 
    int arr[] = { 5, 1, 4, 2, 8 }; 
    int N = 5; 
    bubbleSort(arr, N); 
    return 0; 
}
