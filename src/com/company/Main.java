package com.company;
class Solutions {
    public static void twoSum(int[] nums, int target) {
        int firstnum = 0;
        int firstpos =0;
        int secondnum=0;
        int secondpos=0;
        System.out.println("v");
        for (int cnt=0; cnt < (nums.length); cnt++) {
            if(nums[cnt] < target){
                firstpos = cnt;
                firstnum = nums[cnt];

                for (int i=cnt+1; i< nums.length; i++){

                    if (nums[i] == (target - firstnum)){
                        secondnum = nums[i];
                        secondpos = i;
                        System.out.println(firstpos+"ssec"+secondpos);
                        return;
                    }
                }
            }
        }
       /* int result[] = new int[2];
        result[0]=firstpos;
        result[1]=secondpos;*/

        //system.out.println(firstpos,secondpos);

    }

    public static void main(String args[]){
        int input[] = new int[4];
        input[0]=2;
        input[1]=3;
        input[2]=11;
        input[3]=5;
        twoSum(input,9);

    }
}