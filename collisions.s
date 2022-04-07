; prototype de test de collision au blitter
;
; OK - afficher une zone 256 couleurs avec OL, rempli de pixels
; OK - effacer la zone au blitter
; - sprite en 256 couleurs, masque 1 couleur = 1 type
;		- ennemis
;		- tirs ennemis
;		- vaisseau joueur
;		- tirs joueur
; - blitter 1 sprite sur la zone
; - blitter 1 autre sprite autre couleur
; - idem mais avec test de collision
; - determiner la couleur du pixel destination  de collision
; - version GPU...

	include	"jaguar.inc"


CLEAR_BSS			.equ			1									; 1=efface toute la BSS jusqu'a la fin de la ram utilisée
ob_list_courante			equ		((ENDRAM-$4000)+$2000)				; address of read list
nb_octets_par_ligne			equ		320
nb_lignes					equ		200




.opt "~Oall"

.text



			.68000
	move.l		#INITSTACK, sp	
	move.w		#%0000011011000111, VMODE			; 320x256 256c
	;move.w		#%0000011011000001, VMODE			; 320x256 / CRY / $6C7
	move.w		#$100,JOYSTICK

; clear BSS

	.if			CLEAR_BSS=1
; clear BSS
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0
	
boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2

; clear object list
	lea			ob_list_courante,a0
	lea			ENDRAM,a1
	moveq		#0,d0
	
boucle_clean_BSS3:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS3

	.endif

; mettons des couleurs
		lea		CLUT,a1
		move.w	#0,(a1)+			; 0
		move.w	#$FF00,(a1)+
		move.w	#$71F0,(a1)+		; 2
		move.w	#$FDFF,(a1)+
		move.w	#$FF0F,(a1)+		; 4
		move.w	#$F00F,(a1)+
		move.w	#$F00F,(a1)+
		move.w	#$F00F,(a1)+
		move.w	#$FFFF,(a1)+		; 8
		move.w	#$001F,(a1)+		; couleur 9
		
;check ntsc ou pal:

	moveq		#0,d0
	move.w		JOYBUTS ,d0

	move.l		#26593900,frequence_Video_Clock			; PAL
	move.l		#415530,frequence_Video_Clock_divisee

	
	btst		#4,d0
	beq.s		jesuisenpal
jesuisenntsc:
	move.l		#26590906,frequence_Video_Clock			; NTSC
	move.l		#415483,frequence_Video_Clock_divisee
jesuisenpal:

    bsr     InitVideo               	; Setup our video registers.

	jsr     copy_olist              	; use Blitter to update active list from shadow

	move.l	#ob_list_courante,d0					; set the object list pointer
	swap	d0
	move.l	d0,OLP

	move.l  #VBL,LEVEL0     	; Install 68K LEVEL0 handler
	move.w  a_vde,d0                	; Must be ODD
	sub.w   #16,d0
	ori.w   #1,d0
	move.w  d0,VI

	move.w  #%01,INT1                 	; Enable video interrupts 11101


	;and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	and.w   #$f8ff,sr


; remplit la zone memoire ecran avec des pixels
	lea		zone_fond,a0
	lea		fin_zone_fond,a1
	
boucle_pixels_fond:
	move.b	#1,(a0)+
	move.b	#2,(a0)+
	move.b	#3,(a0)+
	cmp.l	a1,a0
	blt.s	boucle_pixels_fond

	.if		1=1
; effacer le fond au blitter
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#0,A1_PIXEL
	move.l	#PIXEL8|XADDPHR|PITCH1,A1_FLAGS
	move.w	#1,d0
	swap	d0
	move.l	#fin_zone_fond-zone_fond,d1
	move.w	d1,d0
	move.l	d0,B_COUNT
	move.l	#LFU_ZERO|BUSHI,B_CMD
	.endif

; blitter le sprite
; fond AND mask
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(320*40)+32,A1_PIXEL		; X dest=32 / Y dest=40
	move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	#sprite_fond_mask,A2_BASE			; = source
	move.l	#0,A2_PIXEL
	move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS
		
	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	move.l	#SRCEN|DSTEN|LFU_SAD|UPDA1,B_CMD

wait_blitter1:
	move.l   B_CMD,d0             ;; wait for blitter to finish
	ror.w    #1,d0                ;; Check if blitter is idle
	bcc.b    wait_blitter1                ;; bit was clear -> busy
	
; fond OR sprite	
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(320*40)+32,A1_PIXEL		; X dest=32 / Y dest=40
	move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	#sprite_fond,A2_BASE			; = source
	move.l	#0,A2_PIXEL
	move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	move.l	#SRCEN|DSTEN|LFU_SORD|UPDA1,B_CMD

; or de sprite rond double triangle
; 48 = no collision
; 47 = collision
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(320*40)+47,A1_PIXEL		; X dest=32 / Y dest=40
	move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	#sprite_rond,A2_BASE			; = source
	move.l	#0,A2_PIXEL
	move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	move.l	#SRCEN|DSTEN|LFU_SORD|UPDA1,B_CMD
	
	

; avec test de collision
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(320*40)+32,A1_PIXEL		; X dest=32 / Y dest=40
	move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	#sprite_rond,A2_BASE			; = source
	move.l	#0,A2_PIXEL
	move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	;move.l	#SRCEN|DSTEN|LFU_SORD|UPDA1,B_CMD
	
	;move.l	#$09090909,B_PATD
	move.l	#$09,B_PATD
	;move.l	#$0A0A0A0A,B_PATD
	
	
	move.l	#%100,B_STOP
	move.l	#CMPDST|DCOMPEN|DSTEN|B_DSTD|UPDA1,B_CMD
	


; recupere le status
	move.l	B_CMD,d0
	and.l	#%11,d0			; bit0 : 1=idle, bit1 : 1=stopped

	btst	#1,d0
	beq.s	pas_de_collision
	move.w	#$7700,BG
	move.l	#%010,B_STOP
	nop

pas_de_collision:

	move.l	A1_PIXEL,d1				; D1 = pos du stop
	move.l	A1_PIXEL,d2				; D1 = pos du stop

main:
	lea		zone_fond,a0

	bra.s		main
	

;-----------------------------------------------------------------------------------
;--------------------------
; VBL

VBL:
                movem.l d0-d7/a0-a6,-(a7)
				
				;.if		display_infos_debug=1
				;add.w		#1,BG					; debug pour voir si vivant
				;.endif

                ;jsr     copy_olist              	; use Blitter to update active list from shadow

				lea		ob_liste_originale,a0
				lea		ob_list_courante,a1
				lea		fin_ob_liste_originale,a2
VBL_copie_OL:
				move.l		(a0)+,(a1)+
				cmp.l		a0,a2
				bne.s		VBL_copie_OL
		

                addq.l	#1,vbl_counter

                move.w  #$101,INT1              	; Signal we're done
				move.w  #$0,INT2
.exit:
                movem.l (a7)+,d0-d7/a0-a6
                rte



;----------------------------------
; recopie l'object list dans la courante

copy_olist:

				move.l	#ob_list_courante,A1_BASE			; = DEST
				move.l	#$0,A1_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
				move.l	#ob_liste_originale,A2_BASE			; = source
				move.l	#$0,A2_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A2_FLAGS
				move.w	#1,d0
				swap	d0
				move.l	#fin_ob_liste_originale-ob_liste_originale,d1
				move.w	d1,d0
				move.l	d0,B_COUNT
				move.l	#LFU_REPLACE|SRCEN,B_CMD
				rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo 
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Procedure: InitVideo (same as in vidinit.s)
;            Build values for hdb, hde, vdb, and vde and store them.
;            Original code by Atari, slight modifications and comments
;            by Zerosquare / Jagware
                        
InitVideo:
        movem.l d0-d6,-(sp)
            
        move.w  CONFIG,d0     ; Also is joystick register
        andi.w  #VIDTYPE,d0   ; 0 = PAL, 1 = NTSC
        beq     palvals1

        move.w  #NTSC_HMID,d2
        move.w  #NTSC_WIDTH,d0

        move.w  #NTSC_VMID,d6
        move.w  #NTSC_HEIGHT,d4

        bra     calc_vals1
palvals1:
        move.w  #PAL_HMID,d2
        move.w  #PAL_WIDTH,d0

        move.w  #PAL_VMID,d6
        move.w  #PAL_HEIGHT,d4

calc_vals1:
; You can modify d0 and d4 here to set the area drawn 
; by the OP (by default it fills the whole screen). It will
; be centered on the screen.         
; Warning : the horizontal values are in video clock cycles, 
; so don't forget to multiply the number of pixels by 
; PWIDTH + 1
; Check also that the VDB and VDE values used for the first 
; two stop objects in your object list are those calculated 
; here
     
        move.w  d0,d1
        asr     #1,d1         ; Width/2
        
        sub.w   d1,d2         ; Mid - Width/2
        add.w   #4,d2         ; (Mid - Width/2)+4

        sub.w   #1,d1         ; Width/2 - 1
        ori.w   #$400,d1         ; (Width/2 - 1)|$400
        
        move.w  d1,a_hde
        move.w  d1,HDE

        move.w  d2,a_hdb
        move.w  d2,HDB1
        move.w  d2,HDB2

        move.w  d6,d5
        sub.w   d4,d5
		moveq	#0,d5
        move.w  d5,a_vdb

        add.w   d4,d6
        move.w  d6,a_vde

        move.w  a_vdb,VDB
        move.w  a_vde,VDE
            
        movem.l (sp)+,d0-d6
        rts

InitVideo2:
	movem.l d0-d6,-(sp)
			
	move.w	#-1,ntsc_flag
	move.l	#50,_50ou60hertz

	lea		HDE,a1
	lea		HDB1,a2
	lea		HDB2,a3
	lea		VDB,a4
	lea		VDE,a5
	lea		VI,a6

	
	move.w  CONFIG,d0                ; Also is joystick register
	andi.w  #VIDTYPE,d0              ; 0 = PAL, 1 = NTSC
	beq.s    .palvals
	
; NTSC
.ntscvals:
	moveq	#0,d0
	move.w		#1,ntsc_flag
	move.l		#60,_50ou60hertz

	move.w		#$678,(a1)				;HDE
	move.w		#$CB,(a2)				;HDB1
	move.w		#$CB,(a3)				;HDB2
	move.w		#$40,(a4)				;VDB
	move.w		#$242,(a5)				;VDE
	move.w		#$242-16+1,d0
	or.w		#1,d0
	move.w		d0,(a6)					;VI
	move.w	#507,a_vde
			
	bra.s		.sortie
; PAL
.palvals:
	moveq	#0,d0
	move.w		#$66A,(a1)				;HDE
	move.w		#$B7,(a2)				;HDB1
	move.w		#$B7,(a3)				;HDB2
	move.w		#$28,(a4)	            ;VDB
	move.w		#$20A,(a5)				;VDE
	move.w		#$20A-16+1,d0           
	or.w		#1,d0                   
	move.w		d0,(a6)                 ;VI
	move.w	#522,a_vde

			
.sortie:		
	move.l  #0,BORD1                ; Black border
	;move.w  #0,BG                   ; Init line buffer to black
	movem.l (sp)+,d0-d6
	rts


; ------------------
; version invit reboot
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo (same as in vidinit.s)
;;            Build values for hdb, hde, vdb, and vde and store them.
;;

InitVideo3:
                movem.l d0-d6,-(sp)

				
				move.w	#-1,ntsc_flag
	
				move.w  CONFIG,d0                ; Also is joystick register
                andi.w  #VIDTYPE,d0              ; 0 = PAL, 1 = NTSC
                beq     palvals3
				move.w	#1,ntsc_flag

.ntscvals3:		move.w  #NTSC_HMID,d2
                move.w  #NTSC_WIDTH,d0

                move.w  #NTSC_VMID,d6
                move.w  #NTSC_HEIGHT,d4
				
                bra     calc_vals3
palvals3:
				move.w #PAL_HMID,d2
				move.w #PAL_WIDTH,d0

				move.w #PAL_VMID+30,d6				; +30  322
				move.w #PAL_HEIGHT,d4

				
calc_vals3:		
                move.w  d0,width
                move.w  d4,height
                move.w  d0,d1
                asr     #1,d1                   ; Width/2
                sub.w   d1,d2                   ; Mid - Width/2
                add.w   #4,d2                   ; (Mid - Width/2)+4
                sub.w   #1,d1                   ; Width/2 - 1
                ori.w   #$400,d1                ; (Width/2 - 1)|$400
                move.w  d1,a_hde
                move.w  d1,HDE
                move.w  d2,a_hdb
                move.w  d2,HDB1
                move.w  d2,HDB2
                move.w  d6,d5
                sub.w   d4,d5
                add.w   #16,d5
                move.w  d5,a_vdb
                add.w   d4,d6
                move.w  d6,a_vde
                move.w  d5,VDB

;move.w	d6,VDE
				move.w  #$ffff,VDE
                
				move.l  #0,BORD1                ; Black border
                move.w  #0,BG                   ; Init line buffer to black
                movem.l (sp)+,d0-d6
                rts





		.dphrase
        .68000
ob_liste_originale:           				 ; This is the label you will use to address this in 68K code
        .objproc 							   ; Engage the OP assembler

        .org    ob_list_courante			 ; Tell the OP assembler where the list will execute
;
        ;branch      VC < 0, .stahp    			 ; Branch to the STOP object if VC < 0
        ;branch      VC > 310, .stahp   			 ; Branch to the STOP object if VC > 241
			; bitmap data addr, xloc, yloc, dwidth, iwidth, iheight, bpp, pallete idx, flags, firstpix, pitch
; zone 256c 8 bits
        bitmap      zone_fond, 20, 30, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 200,3
		;bitmap		ecran1,16,24,40,40,255,3
        ;jump        .haha
.stahp:
        stop
.haha:
        ;jump        .stahp
		
		.68000
		.dphrase
fin_ob_liste_originale:


			.data
	.dphrase

stoplist:		dc.l	0,4

.phrase
sprite_fond:
; 16x16 256 couleurs
	.rept	16
	.rept	6
	dc.b	1
	.endr
	dc.b	0,0,0,0
	.rept	6
	dc.b	1
	.endr
	.endr
	
fin_sprite_fond:

sprite_fond_mask:
; 16x16 256 couleurs
	.rept	16
	.rept	6
	dc.b	$0
	.endr
	dc.b	$FF,$FF,$FF,$FF
	.rept	6
	dc.b	$0
	.endr
	.endr

sprite_rond:
	dc.b			0,0,0,0,0,0,0,8,8,0,0,0,0,0,0,0
	dc.b			0,0,0,0,0,0,8,8,8,8,0,0,0,0,0,0
	dc.b			0,0,0,0,0,8,8,8,8,8,8,0,0,0,0,0
	dc.b			0,0,0,0,8,8,8,8,8,8,8,8,0,0,0,0
	dc.b			0,0,0,8,8,8,8,8,8,8,8,8,8,0,0,0
	dc.b			0,0,8,8,8,8,8,8,8,8,8,8,8,8,0,0
	dc.b			0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
	dc.b			8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8
	dc.b			0,0,0,0,0,0,0,8,8,0,0,0,0,0,0,0
	dc.b			0,0,0,0,0,0,8,8,8,8,0,0,0,0,0,0
	dc.b			0,0,0,0,0,8,8,8,8,8,8,0,0,0,0,0
	dc.b			0,0,0,0,8,8,8,8,8,8,8,8,0,0,0,0
	dc.b			0,0,0,8,8,8,8,8,8,8,8,8,8,0,0,0
	dc.b			0,0,8,8,8,8,8,8,8,8,8,8,8,8,0,0
	dc.b			0,8,8,8,8,8,8,8,8,8,8,8,8,8,8,0
	dc.b			8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8
	


	.bss	
	.phrase
DEBUT_BSS:
frequence_Video_Clock:					ds.l				1
frequence_Video_Clock_divisee :			ds.l				1


_50ou60hertz:			ds.l	1
taille_liste_OP:		ds.l	1
vbl_counter:			ds.l	1
ntsc_flag:				ds.w	1
a_hdb:          		ds.w   1
a_hde:          		ds.w   1
a_vdb:          		ds.w   1
a_vde:          		ds.w   1
width:          		ds.w   1
height:         		ds.w   1

.dphrase
zone_fond:			ds.b		320*200
fin_zone_fond:

FIN_RAM: