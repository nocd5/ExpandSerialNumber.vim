ExpandSerialNumber.vim
======================
Expand serial number.
support back-refarence and calculation with eval() of Vim.

## usage
:Expandserialnumber

## known problem
if expanded at end of text, blank line is inserted at the end

## example
### 1.
expand simple format
#### source
>[1-3]

#### dest
>1

>2

>3

### 2.
expand hexadecimal value
#### source
>[0x8-0xb]

#### dest
>8

>9

>a

>b

### 3.
back-refarence
#### source
>[1-3],[\1]

#### dest
>1,1

>2,2

>3,3

### 4.
back-refarence and arithmetic
#### source
>[1-3],[\1+1]

#### dest
>1,2

>2,3

>3,4

### 5.
multiple back-refarence and arithmetic
#### source
>[1-3]+[4-5]=[\1+\2]

#### dest
>1+4=5

>1+5=6

>2+4=6

>2+5=7

>3+4=7

>3+5=8

### 6.
calculation which can be treated by eval()
#### source
>[printf("0x%0x",float2nr(pow([2-3],[4-5])))]=[\1]^[\2]

#### dest
>0x10=2^4

>0x20=2^5

>0x51=3^4

>0xf3=3^5
