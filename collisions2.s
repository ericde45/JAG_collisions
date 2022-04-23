; prototype de test de collision au GPU
; http://patrice.mandin.pagesperso-orange.fr/fr/howto-prog.html
;
; OK - afficher une zone CRY avec OL, rempli de pixels
; OK - effacer la zone au blitter
; OK - sprite en CRY
; OK - blitter 1 sprite sur la zone
; OK - blitter 1 autre sprite 
; OK - test de collision
; OK - tests tout autour
; - optimiser nb de registres ?


	include	"jaguar.inc"

;-------------------------
;CC (Carry Clear) = %00100
;CS (Carry Set)   = %01000
;EQ (Equal)       = %00010
;MI (Minus)       = %11000
;NE (Not Equal)   = %00001
;PL (Plus)        = %10100	= + ou egal ?
;HI (Higher)      = %00101
;T (True)         = %00000
;-------------------------


CLEAR_BSS			.equ			1									; 1=efface toute la BSS jusqu'a la fin de la ram utilisée
ob_list_courante			equ		((ENDRAM-$4000)+$2000)				; address of read list
nb_octets_par_ligne			equ		640
nb_lignes					equ		200

CLS		equ		1

GPU_STACK_SIZE	equ		32	; long words
GPU_USP			equ		(G_ENDRAM-(4*GPU_STACK_SIZE))
GPU_ISP			equ		(GPU_USP-(4*GPU_STACK_SIZE))

taille_maximale_sprite_ennemi_mobile_X			equ		16
taille_maximale_sprite_ennemi_mobile_Y			equ		16

nb_octets_ligne_image_sprites	equ		640


.opt "~Oall"

.text



			.68000
	move.l		#INITSTACK, sp	
	;move.w		#%0000011011000111, VMODE			; 320x256 256c
	move.w		#%0000011011000001, VMODE			; 320x256 / CRY / $6C7
	move.w		#$100,JOYSTICK

	lea		png_sprites,a0

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

; copie du code GPU
	move.l	#0,G_CTRL
; copie du code GPU dans la RAM GPU

	lea		GPU_debut,A0
	lea		G_RAM,A1
	move.l	#GPU_fin-GPU_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_GPU:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_GPU

		
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
	
	move.w	#$7777,d0
	move.w	#$FFFF,d1
	
boucle_pixels_fond:
	move.w	d0,(a0)+
	move.w	d1,(a0)+
	cmp.l	a1,a0
	blt.s	boucle_pixels_fond

	.if		CLS=1
; effacer le fond au blitter
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#0,A1_PIXEL
	move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
; 320*200*2 = 

	move.w	#4,d0
	swap	d0
	move.w	#16000,d0
	
	sub.l	#1000,d0				; laisse en bas un peu de graph pour temoin
	
	move.l	#fin_zone_fond-zone_fond,d1
	move.l	d0,B_COUNT
	move.l	#LFU_ZERO,B_CMD
	.endif


; -----------------------------------------------------------------------------------
; test de sprites en 1 passe:
;B_CMD :
;- SRCEN => activation de la lecture data source
;- DSTEN => activation de la lecture data destination
;- LFU_REPLACE => écrire SOURCE
;- DCOMPEN => activation du test "if B_PATD = source"

;B_PATD
;- initialisé avec la valeur "0x0000 0000 0000 0000" (64-bit)


	move.l	#zone_fond,A1_BASE			; = DEST
	move.w	Y_sprite1,d0
	swap	d0
	move.w	X_sprite1,d0
	
	move.l	d0,A1_PIXEL		; X et Y sprite 1
	move.l	#PIXEL16|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	data_sprite1,A2_BASE			; = source  =$08
	move.l	#0,A2_PIXEL
	move.l	#PIXEL16|XADDPIX|PITCH1|WID320,A2_FLAGS

	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A2_STEP 

	move.l	#$00,B_PATD

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	move.l	#SRCEN|DSTEN|LFU_REPLACE|UPDA1|UPDA2|DCOMPEN,B_CMD

; blitt du sprite2
	move.l	#zone_fond,A1_BASE			; = DEST
	move.w	Y_sprite2,d0
	swap	d0
	move.w	X_sprite2,d0
	
	move.l	d0,A1_PIXEL		; X et Y sprite 1
	move.l	#PIXEL16|XADDPIX|PITCH1|WID320,A1_FLAGS
	move.l	#320,A1_CLIP
	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A1_STEP 
	move.l	#0,A1_FSTEP
	
	move.l	data_sprite2,A2_BASE			; = source  =$08
	move.l	#0,A2_PIXEL
	move.l	#PIXEL16|XADDPIX|PITCH1|WID320,A2_FLAGS

	move.w   #1,d0
	swap     d0
	move.w   #-16,d0
	move.l   d0,A2_STEP 

	move.l	#$00,B_PATD

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT
	move.l	#SRCEN|DSTEN|LFU_REPLACE|UPDA1|UPDA2|DCOMPEN,B_CMD



	.if		1=0


; -----------------------------------------------------------------------------------
; deuxieme test de collision, en 1 passe
; fond deja blitté = destination = $08
; sprite source = $01



	;;move.l	#zone_fond,A1_BASE			; = DEST

; collision:
	;move.l	#(45<<16)+100+5,A1_PIXEL		; X dest=32 / Y dest=40
	
; pas de collision, les 4 pixels sont entre les 2 colonnes
	move.l	#(45<<16)+100,A1_PIXEL		; X dest=32 / Y dest=40

	move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS

	move.l	#sprite_point,A2_BASE			; = source =$01
	move.l	#0,A2_PIXEL
	move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS

	move.w	#16,d0			; 16 lignes
	swap	d0
	move.w	#16,d0			; 16 pixels de largeur
	move.l	d0,B_COUNT


	;move.l	#$09090909,B_PATD			; KO
	;move.l	#$09,B_PATD					; KO pas de collision meme si collision
	;move.l	#$08,B_PATD					; 

	move.l	#$08080808,B_PATD+4			; KO : chercher 08 => collisions, meme quand pas de collisions
	move.l	#$08080808,B_PATD			; KO : chercher 08 => collisions, meme quand pas de collisions

	;move.l	#$09090909,B_PATD+4			; KO : ne trouve jamais de collisions
	;move.l	#$09090909,B_PATD			; KO : ne trouve jamais de collisions

	;move.l	#$01010101,B_PATD+4			; ne trouve jamais de collisions
	;move.l	#$01010101,B_PATD			; ne trouve jamais de collisions

	;move.l	#$01,B_PATD			; KO
	
	move.l	#%100,B_STOP
	move.l	#SRCEN|DSTEN|CMPDST|DCOMPEN|LFU_SORD|UPDA1,B_CMD				; affiche les parties qui ne sont pas en collision
	;move.l	#SRCEN|DSTEN|CMPDST|DCOMPEN|LFU_D|UPDA1,B_CMD					; n'affiche rien
	;move.l	#SRCEN|DSTEN|LFU_SORD|UPDA1|UPDA2,B_CMD							; pas de test de collision, fais un OR
	
	
	;move.l	#SRCEN|DSTEN|CMPDST|LFU_D|UPDA1,B_CMD					; n'affiche rien


; recupere le status
	move.l	B_CMD,d0
	and.l	#%11,d0			; bit0 : 1=idle, bit1 : 1=stopped

	btst	#1,d0
	beq.s	pas_de_collision2
	move.w	#$7000,BG
	move.l	#%010,B_STOP
	nop

pas_de_collision2:


	move.l	A1_PIXEL_R,d1				; D1 = pos du stop
	move.l	A2_PIXEL_R,d2				; D1 = pos du stop


	.endif
	
; test de collision au GPU
; launch GPU
	move.l	#REGPAGE,G_FLAGS
	move.l	#GPU_init,G_PC
	move.l  #RISCGO,G_CTRL	; START GPU

; attente du GPU
	lea		G_CTRL,a0
wait_end_GPU:
	move.l	(a0),d0
	btst	#0,d0
	bne.s	wait_end_GPU

	move.l	GPU_resultat_collision,d0

	cmp.l	#0,d0
	beq.s	pas_dde_changement_de_couleur_de_fond_car_pas_de_collision
	move.w	#$F7F0,BG
	
	
pas_dde_changement_de_couleur_de_fond_car_pas_de_collision:

main:
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


; ------------------------------------------------------------------
;
;  code GPU
;
; ------------------------------------------------------------------
	.phrase
GPU_debut:

	.gpu
	.org	G_RAM
GPU_base_memoire:

; CPU interrupt
	.rept	8
		nop
	.endr
; DSP interrupt, the interrupt output from Jerry
	.rept	8
		nop
	.endr
; Timing generator
	.rept	8
		nop
	.endr
; Object Processor
	.rept	8
		nop
	.endr
; Blitter
	.rept	8
		nop
	.endr

GPU_init:
	movei	#GPU_ISP+(GPU_STACK_SIZE*4),r31			; init isp
	moveq	#0,r1
	moveta	r31,r31									; ISP (bank 0)
	nop
	movei	#GPU_USP+(GPU_STACK_SIZE*4),r31			; init usp

; test de collision
; R0
; R1 = source datas sprite 1
; R2 = source datas sprite 2
Xsprite1				.equr	R3
Xsprite2				.equr	R4
Ysprite1				.equr	R5
Ysprite2				.equr	R6
DATA_sprite1			.equr	R7
DATA_sprite2			.equr	R8
GPU_CX1					.equr	R9
Xsprite1_plus_W1		.equr	R10
Xsprite2_plus_W2		.equr	R11
GPU_CX2					.equr	R12
saut_boucle_de_test_en_X	.equr	R12
GPU_CY1					.equr	R13
compteur_X				.equr	R14
; R15
;compteur_Y				.equr	R15 ( reutilise Ysprite2)
Ysprite1_plus_H1		.equr	R16
Ysprite2_plus_H2		.equr	R17
GPU_CY2					.equr	R18
saut_boucle_de_test_en_Y	.equr	R18
GPU_CW					.equr	R19
GPU_CH					.equr	R20
valeur_data_sprite1		.equr	R21
valeur_data_sprite2		.equr	R22
resultat_collision		.equr	R23
; R24
; R25

mask_FFFF				.equr	R26
saut_pas_de_collision	.equr	R27


; w1 = taille_maximale_sprite_ennemi_mobile_X			equ		16
; h1 = taille_maximale_sprite_ennemi_mobile_Y			equ		16


	movei	#GPU_fin_test_collision,saut_pas_de_collision
	movei	#$FFFF,mask_FFFF
	moveq	#0,resultat_collision
	movei	#X_sprite1,R1
	movei	#X_sprite2,R2
	load	(R1),Xsprite1						; X1 et Y1
	load	(R2),Xsprite2						; X2 et Y2
	addq	#4,R1
	move	Xsprite1,Ysprite1
	addq	#4,R2
	move	Xsprite2,Ysprite2
	load	(R1),DATA_sprite1
	and		mask_FFFF,Ysprite1
	load	(R2),DATA_sprite2
	and		mask_FFFF,Ysprite2
	sharq	#16,Xsprite1
	sharq	#16,Xsprite2
	
; cx=max(x1,x2)
	cmp		Xsprite1,Xsprite2
	jr		mi,Xsprite2_inf_Xsprite1
	nop
	move	Xsprite2,GPU_CX1
	jr		GPU_suite1
	nop
Xsprite2_inf_Xsprite1:
	move	Xsprite1,GPU_CX1
GPU_suite1:

; cx2=min(x1+w1,x2+w2)
	move	Xsprite1,Xsprite1_plus_W1
	move	Xsprite2,Xsprite2_plus_W2
	addq	#taille_maximale_sprite_ennemi_mobile_X,Xsprite1_plus_W1
	addq	#taille_maximale_sprite_ennemi_mobile_X,Xsprite2_plus_W2
	
	cmp		Xsprite1_plus_W1,Xsprite2_plus_W2
	jr		mi,Xsprite2_plus_W2_INF_Xsprite1_plus_W1
	nop
	move	Xsprite1_plus_W1,GPU_CX2
	jr		GPU_suite2
	nop
Xsprite2_plus_W2_INF_Xsprite1_plus_W1:
	move	Xsprite2_plus_W2,GPU_CX2
GPU_suite2:

; if (cx2<cx) stop:pas de collision
	cmp		GPU_CX1,GPU_CX2
	jump	mi,(saut_pas_de_collision)
	nop

; cy=max(y1,y2)
	cmp		Ysprite1,Ysprite2
	jr		mi,Ysprite2_inf_Ysprite1
	nop
	move	Ysprite2,GPU_CY1
	jr		GPU_suite3
	nop
Ysprite2_inf_Ysprite1:
	move	Ysprite1,GPU_CY1
GPU_suite3:

; cy2=min(y1+h1,y2+h2)
	move	Ysprite1,Ysprite1_plus_H1
	move	Ysprite2,Ysprite2_plus_H2
	addq	#taille_maximale_sprite_ennemi_mobile_Y,Ysprite1_plus_H1
	addq	#taille_maximale_sprite_ennemi_mobile_Y,Ysprite2_plus_H2
	
	cmp		Ysprite1_plus_H1,Ysprite2_plus_H2
	jr		mi,Ysprite2_plus_H2_INF_Ysprite1_plus_H1
	nop
	move	Ysprite1_plus_H1,GPU_CY2
	jr		GPU_suite4
	nop
Ysprite2_plus_H2_INF_Ysprite1_plus_H1:
	move	Ysprite2_plus_H2,GPU_CY2
GPU_suite4:

; if (cy2<cy) stop:pas de collision
	cmp		GPU_CY1,GPU_CY2
	jump	mi,(saut_pas_de_collision)
	nop

; cw=cx2-cx
; ch=cy2-cy
	move	GPU_CX2,GPU_CW
	move	GPU_CY2,GPU_CH
	sub		GPU_CX1,GPU_CW
	sub		GPU_CY1,GPU_CH

; coordonnées de la zone d'intersection (cx,cy,cw,ch)
; cx1=cx2=cy1=cy2=0
	moveq	#0,GPU_CX1
	moveq	#0,GPU_CX2
	moveq	#0,GPU_CY1
	moveq	#0,GPU_CY2

;if (x1<x2) cx1=x2-x1
	cmp		Xsprite1,Xsprite2
	jr		mi,Xsprite2_INF_Xsprite1_2
	nop
	move	Xsprite2,GPU_CX1
	sub		Xsprite1,GPU_CX1
	jr		GPU_test_Y
	nop
; x2<x1
; if (x2<x1) cx2=x1-x2
Xsprite2_INF_Xsprite1_2:
	move	Xsprite1,GPU_CX2
	sub		Xsprite2,GPU_CX2

GPU_test_Y:

; if (y1<y2) cy1=y2-y1
	cmp		Ysprite1,Ysprite2
	jr		mi,Ysprite2_INF_Ysprite1_2
	nop
	move	Ysprite2,GPU_CY1
	sub		Ysprite1,GPU_CY1
	jr		GPU_suite5
	nop
; y2<y1
; if (y2<y1) cy2=y1-y2
Ysprite2_INF_Ysprite1_2:
	move	Ysprite1,GPU_CY2
	sub		Ysprite2,GPU_CY2

GPU_suite5:

; cx1,cy1,cw,ch est la zone d'intersection dans le sprite 1.
; cx2,cy2,cw,ch est la zone d'intersection dans le sprite 2.

; il faut positionner DATA_sprite1 et DATA_sprite2 au debut

; on re-utilise 1 registre
GPU_valeur_octets_par_ligne_ajout_en_Y		.equr		Xsprite2

	movei	#nb_octets_ligne_image_sprites,GPU_valeur_octets_par_ligne_ajout_en_Y
	add		GPU_CX1,DATA_sprite1		; + debut en X
	mult	GPU_valeur_octets_par_ligne_ajout_en_Y,GPU_CY1
	add		GPU_CX1,DATA_sprite1		; + debut en X		*2 car 1 pixel = 2 octets
	add		GPU_CX2,DATA_sprite2		; + debut en X
	mult	GPU_valeur_octets_par_ligne_ajout_en_Y,GPU_CY2
	add		GPU_CX2,DATA_sprite2		; + debut en X		*2 car 1 pixel = 2 octets

	add		GPU_CY1,DATA_sprite1
	movei	#boucle_de_test_en_X,saut_boucle_de_test_en_X
	add		GPU_CY2,DATA_sprite2

compteur_Y		.equr		Ysprite2

; ajuster l'increment en fin de ligne, en fonction du nb de pixels lus en X
	sub		GPU_CW,GPU_valeur_octets_par_ligne_ajout_en_Y
	move	GPU_CH,compteur_Y
	movei	#boucle_de_test_en_Y,saut_boucle_de_test_en_Y
	sub		GPU_CW,GPU_valeur_octets_par_ligne_ajout_en_Y				; *2 car 1 pixel = 2 octets
	
; on doit lire GPU_CW octets par ligne
; sur GPU_CH lignes


boucle_de_test_en_Y:
	move	GPU_CW,compteur_X

boucle_de_test_en_X:
	loadw	(DATA_sprite1),valeur_data_sprite1			; data du sprite 1
	;or		valeur_data_sprite1,valeur_data_sprite1
	cmpq	#0,valeur_data_sprite1
	jr		eq,avance_prochain_pixel
	addqt	#2,DATA_sprite1
	
	loadw	(DATA_sprite2),valeur_data_sprite2
	;or		valeur_data_sprite2,valeur_data_sprite2
	cmpq	#0,valeur_data_sprite2
	jr		ne,GPU_il_y_a_collision_et_sortie
	
avance_prochain_pixel:
	addqt	#2,DATA_sprite2
	
	subq	#1,compteur_X
	jump	hi,(saut_boucle_de_test_en_X)
	nop

; incremente DATA sprite1 et 2
	add		GPU_valeur_octets_par_ligne_ajout_en_Y,DATA_sprite1					; ligne suivante = +640
	add		GPU_valeur_octets_par_ligne_ajout_en_Y,DATA_sprite2					; ligne suivante = +640

	subq	#1,compteur_Y
	jump	hi,(saut_boucle_de_test_en_Y)
	nop

	jr		GPU_fin_test_collision
	nop

GPU_il_y_a_collision_et_sortie:
	moveq	#1,resultat_collision


GPU_fin_test_collision:

	movei	#GPU_resultat_collision,GPU_valeur_octets_par_ligne_ajout_en_Y
	movei	#G_CTRL,compteur_X
	store	resultat_collision,(GPU_valeur_octets_par_ligne_ajout_en_Y)
	nop
	moveq	#0,compteur_Y
	store	compteur_Y,(compteur_X)					; stop le GPU

	nop
	nop
	nop
	nop




GPU_resultat_collision:			dc.l		0

;---------------------
; FIN DE LA RAM GPU
GPU_fin:
;---------------------	

GPU_DRIVER_SIZE			.equ			GPU_fin-GPU_base_memoire
	.print	"--- GPU code size : ", /u GPU_DRIVER_SIZE, " bytes / 4096 ---"

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
        bitmap      zone_fond, 20, 30, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 200,4
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
X_sprite1:		dc.w		100
Y_sprite1:		dc.w		40
data_sprite1:	dc.l		png_sprites

X_sprite2:		dc.w		92								; 113+ = pas de collision
Y_sprite2:		dc.w		28
data_sprite2:	dc.l		png_sprites+(640*96)




.phrase
sprite_fond:
; 16x16 256 couleurs
	.rept	16
	.rept	6
	dc.b	8
	.endr
	dc.b	0,0,0,0
	.rept	6
	dc.b	8
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
	dc.b			0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0
	dc.b			0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0
	dc.b			0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0
	dc.b			0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
	dc.b			0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b			0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b			0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
	dc.b			1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	dc.b			0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0
	dc.b			0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0
	dc.b			0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0
	dc.b			0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
	dc.b			0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
	dc.b			0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
	dc.b			0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0
	dc.b			1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

sprite_point:
	.rept	7
	.rept	16
	dc.b	0
	.endr
	.endr
	dc.b			0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0
	dc.b			0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0
	.rept	7
	.rept	16
	dc.b	0
	.endr
	.endr
	
	.phrase
png_sprites:
	.incbin		"test01_21042022.png_JAG_CRY"
	even
	.phrase

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
zone_fond:
; en CRY
			ds.b		320*200*2
fin_zone_fond:

FIN_RAM:

.if		1=0

; blitter le sprite
; fond AND mask
	move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(40<<16)+32,A1_PIXEL		; X dest=32 / Y dest=40
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
	move.l	#(0<<16)+0,A1_PIXEL		; X dest=32 / Y dest=40
	;move.l	#(40<<16)+32,A1_PIXEL		; X dest=32 / Y dest=40
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
	move.l	#(0<<16)+0+15,A1_PIXEL		; X dest=32 / Y dest=40
	;move.l	#(40<<16)+32+15,A1_PIXEL		; X dest=32 / Y dest=40
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
	;move.l	#zone_fond,A1_BASE			; = DEST
	move.l	#(40<<16)+32+15,A1_PIXEL		; X dest=32 / Y dest=40
	;move.l	#PIXEL8|XADDPIX|PITCH1|WID320,A1_FLAGS
	;move.l	#320,A1_CLIP
	;move.w   #1,d0
	;swap     d0
	;move.w   #-16,d0
	;move.l   d0,A1_STEP 
	;move.l	#0,A1_FSTEP
	
	;move.l	#sprite_rond,A2_BASE			; = source
	;move.l	#0,A2_PIXEL
	;move.l	#PIXEL8|XADDPIX|PITCH1|WID16,A2_FLAGS

	;move.w	#16,d0			; 16 lignes
	;swap	d0
	;move.w	#16,d0			; 16 pixels de largeur
	;move.l	d0,B_COUNT
	
	move.l	#$09090909,B_PATD

	
	move.l	#%100,B_STOP
	move.l	#CMPDST|DCOMPEN|DSTEN|LFU_D|UPDA1,B_CMD
	

	move.l	A1_PIXEL_R,d3				; D1 = pos du stop
	move.l	A2_PIXEL_R,d4				; D1 = pos du stop

; recupere le status
	move.l	B_CMD,d0
	and.l	#%11,d0			; bit0 : 1=idle, bit1 : 1=stopped

	btst	#1,d0
	beq.s	pas_de_collision
	move.w	#$7700,BG				; 7700=violet
	move.l	#%010,B_STOP			; abort
	nop

pas_de_collision:

	move.l	A1_PIXEL_R,d1				; D1 = pos du stop
	move.l	A2_PIXEL_R,d2				; D1 = pos du stop
	
	
	
; =6 pour objet a droite, 1 pixel de chevauchement
; =$000F0002 pour objet 1 pixel commun, positioné a gauche
; au dessus : collision uniquement en bas a droite 1 pixel : 0806
; en dessous : 
.endif
