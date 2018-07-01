;-------------------------------------------------------------------------------
;
; Software Protection Library 0.11
;
; This library contains a set of functions to generate a registration key
; based on a user fingerprint.
; To be used separately or together with the GUI library - SWProtect-GUI.ahk
; 
; Original Code:    Laszlo Hars <www.Hars.US>
; Library Version:  Icarus
;
; Original proof of concept by Laszlo, taken from AutoHotkey Forum at
; http://www.autohotkey.com/forum/viewtopic.php?t=5763&postdays=0&postorder=asc&start=0
;
;
; Functions in this version
; 
  SWP_Initialize( 0x81645731, 0x19573548 )
   Fingerprint := SWP_GetPcFingerprint()
   UserOK      := SWP_IsUserAuthenticated( username, email, key )
   Key         := SWP_GenerateKey( username, email, fingerprint )
;
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
; TESTER - Comment or delete this tester when including the file
;

/*

; Initialize the required globals
;----------------------------------------
SWP_Initialize(0x81645731, 0x19573548)        ; May be called with up to 8 secret keys


; Get a hardware fingerprint
;----------------------------------------
Fingerprint := SWP_GetPcFingerprint()
MsgBox 32,,Your computer ID is`n%Fingerprint%


; Generate a license key for this user
;----------------------------------------
Username    := "Icarus"
Email       := "Icarus@Sky.com"
key         := SWP_GenerateKey( Username, Email, Fingerprint )
MsgBox 32,,Your registration details are:`nUser:`t%Username%`nEmail:`t%Email%`nKey:`t%Key%


; Check if a user's registration code is ok
;----------------------------------------
;Key := "some invalid key by the user"                      ; Uncomment to test
UserOK      := SWP_IsUserAuthenticated( Username, Email, Key )
If( UserOK )
    MsgBox 32,OK,User is authenticated
Else
    MsgBox 16,INVALID,User is NOT authenticated`n%Username%`n%Email%`n%Key%
    
    
Return



*/
;
; END OF TESTER
;-------------------------------------------------------------------------------




;-------------------------------------------------------------------------------
; API Functions
;-------------------------------------------------------------------------------
;  
; SWP_Initialize( [ secret1, secret 2, ... , secret 8 ] )
; Fingerprint := SWP_GetPcFingerprint()
; UserOK      := SWP_IsUserAuthenticated( username, email, key )
; Key         := SWP_GenerateKey( username, email, fingerprint )
;
;-------------------------------------------------------------------------------
SWP_Initialize( mk0=0x11111111, mk1=0x22222222, mk2=0x33333333, mk3=0x44444444
    ,ml0=0x12345678, ml1=0x12345678, mm0=0x87654321, mm1=0x87654321 ) {
    
    Global

    k0 := mk0                  ; 128-bit secret key (example)
    k1 := mk1
    k2 := mk2
    k3 := mk3
    
    l0 := ml0                  ; 64- bit 2nd secret key (example)
    l1 := ml1
    
    m0 := mm0                  ; 64- bit 3rd secret key (example)
    m1 := mm1

}


SWP_GetPcFingerprint() {
    PCdata = %COMPUTERNAME%%HOMEPATH%%USERNAME%%PROCESSOR_ARCHITECTURE%%PROCESSOR_IDENTIFIER%
    PCdata = %PCdata%%PROCESSOR_LEVEL%%PROCESSOR_REVISION%%A_OSType%%A_OSVersion%%Language%

    Fingerprint := XCBC(Hex(PCdata,StrLen(PCdata)), 0,0, 0,0,0,0, 1,1, 2,2)
    Return Fingerprint
}

SWP_GenerateKey( username, email, fingerprint ) {
    Global k0,k1,k2,k3,l0,l1,m0,m1
    
    If( not k0 ) {
        MsgBox 16,Error,Error in SWP_GenerateKey - values are not initialized.`nPlease call SWP_Initialize() first.
        Return false
    }
        
    Together = %username%%email%%fingerprint%
    Auth := XCBC(Hex(Together,StrLen(Together)), 0,0, k0,k1,k2,k3, l0,l1, m0,m1)
    Return Auth
}


SWP_IsUserAuthenticated( username, email, key ) {
    Global k0,k1,k2,k3,l0,l1,m0,m1
    
    If( not k0 ) {
        MsgBox 16,Error,Error in SWP_IsUserAuthenticated - values are not initialized.`nPlease call SWP_Initialize() first.
        Return false
    }

    Fingerprint := SWP_GetPcFingerprint()
    Together = %username%%email%%Fingerprint%

    AuthData := XCBC(Hex(Together,StrLen(Together)), 0,0, k0,k1,k2,k3, l0,l1, m0,m1)
    
    Return Key=AuthData
}




;-------------------------------------------------------------------------------
; Internal Functions by Laszlo
;-------------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; TEA cipher ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Block encryption with the TEA cipher
; [y,z] = 64-bit I/0 block
; [k0,k1,k2,k3] = 128-bit key
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TEA(ByRef y,ByRef z, k0,k1,k2,k3)
{                                   ; need  SetFormat Integer, D
   s = 0
   d = 0x9E3779B9
   Loop 32                          ; could be reduced to 8 for speed
   {
      k := "k" . s & 3              ; indexing the key
      y := 0xFFFFFFFF & (y + ((z << 4 ^ z >> 5) + z  ^  s + %k%))
      s := 0xFFFFFFFF & (s + d)  ; simulate 32 bit operations
      k := "k" . s >> 11 & 3
      z := 0xFFFFFFFF & (z + ((y << 4 ^ y >> 5) + y  ^  s + %k%))
   }
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; XCBC-MAC ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; x  = long hex string input
; [u,v] = 64-bit initial value (0,0)
; [k0,k1,k2,k3] = 128-bit key
; [l0,l1] = 64-bit key for not padded last block
; [m0,m1] = 64-bit key for padded last block
; Return 16 hex digits (64 bits) digest
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

XCBC(x, u,v, k0,k1,k2,k3, l0,l1, m0,m1)
{
   Loop % Ceil(StrLen(x)/16)-1   ; full length intermediate message blocks
      XCBCstep(u, v, x, k0,k1,k2,k3)

   If (StrLen(x) = 16)              ; full length last message block
   {
      u := u ^ l0                   ; l-key modifies last state
      v := v ^ l1
      XCBCstep(u, v, x, k0,k1,k2,k3)
   }
   Else {                           ; padded last message block
      u := u ^ m0                   ; m-key modifies last state
      v := v ^ m1
      x = %x%100000000000000
      XCBCstep(u, v, x, k0,k1,k2,k3)
   }
   Return Hex8(u) . Hex8(v)         ; 16 hex digits returned
}

XCBCstep(ByRef u, ByRef v, ByRef x, k0,k1,k2,k3)
{
   StringLeft  p, x, 8              ; Msg blocks
   StringMid   q, x, 9, 8
   StringTrimLeft x, x, 16
   p = 0x%p%
   q = 0x%q%
   u := u ^ p
   v := v ^ q
   TEA(u,v,k0,k1,k2,k3)
}

Hex8(i)                             ; 32-bit integer -> 8 hex digits
{
   format = %A_FormatInteger%       ; save original integer format
   SetFormat Integer, Hex
   i += 0x100000000                 ; convert to hex, set MS bit
   StringTrimLeft i, i, 3           ; remove leading 0x1
   SetFormat Integer, %format%      ; restore original format
   Return i
}

Hex(ByRef b, n=0)                   ; n bytes data -> stream of 2-digit hex
{                                   ; n = 0: all (SetCapacity can be larger than used!)
   format = %A_FormatInteger%       ; save original integer format
   SetFormat Integer, Hex           ; for converting bytes to hex

   m := VarSetCapacity(b)
   If (n < 1 or n > m)
       n := m
   Loop %n%
   {
      x := 256 + *(&b+A_Index-1)    ; get byte in hex, set 17th bit
      StringTrimLeft x, x, 3        ; remove 0x1
      h = %h%%x%
   }
   SetFormat Integer, %format%      ; restore original format
   Return h
}


;-------------------------------------------------------------------------------
; Revision History
;-------------------------------------------------------------------------------
/*

    0.11  2007 09 04
        - Fixed  : IsUserAuthenticated returned -1 in case of an uninitialized
                   globals, now returning false.
        
    0.10  2007 09 03
        - First version



*/