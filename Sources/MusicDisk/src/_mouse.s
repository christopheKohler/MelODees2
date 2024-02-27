;---------------------------------------------------------------
;	Souris
;---------------------------------------------------------------
m1:	dc.w	0
m2:	dc.w	0
m1s:	dc.w	0
m2s:	dc.w	0
m1r:	dc.w	0
m2r:	dc.w	0
m1rs:	dc.w	0
m2rs:	dc.w	0
;---------------------------------------------------------------
Move_sprite:			; Test touche pour deplacement curseur
	Lea	m1,a1
	Lea	m1s,a2
	Move.l	(a1),(a2)
	Lea	m1r,a1
	Lea	m1rs,a2
	Move.l	(a1),(a2)
				; coordonnees de la souris
	Clr.l	d1
	Move.w	$dff00a,d1
	And.w 	#$00ff,d1
	Move.w	d1,m1		; M1 = X actuel
	Move.w 	$dff00a,d1
	Lsr.w	#8,d1
	And.w 	#$00ff,d1
	Move.w	d1,m2		; M2 = Y actuel
				; converi en relatif
	Lea	m1,a1
	Move.w	(a1),d1
	Lea	m1s,a1
	Move.w	(a1),d2
	Sub.w	d2,d1
	Move.w	d1,m1r		; Resultat en relatif X = M1r
	lea	m2,a1
	move.w	(a1),d1
	lea	m2s,a1
	move.w	(a1),d2
	sub.w	d2,d1
	move.w	d1,m2r		; Resultat en relatif Y = M2r
				; regle le depassement
Vm=125
	Cmp.w	#Vm,m1r
	Bmi.b	lp
	Move.w	m1rs,m1r	
Lp:	Cmp.w	#-Vm,m1r
	Bpl.b	lp1
	Move.w	m1rs,m1r	
lp1:	Cmp.w	#Vm,m2r
	Bmi.b	lp3
	Move.w	m2rs,m2r	
lp3:	Cmp.w	#-Vm,m2r
	Bpl.b	lp4
	Move.w	m2rs,m2r	
lp4:
	cmp.w	#0,m1r
	bpl.b	B_D
	move.w	m1r,d0
	neg	d0
	Add.w	d0,mouse_g
b_d	cmp.w	#0,m1r
	bmi.b	B_g
	move.w	m1r,d0
	Add.w	d0,mouse_d
b_g	cmp.w	#0,m2r
	bpl.b	B_h
	move.w	m2r,d0
	neg	d0
	Add.w	d0,mouse_h
b_h	cmp.w	#0,m2r
	bmi.b	B_b
	move.w	m2r,d0
	Add.w	d0,mouse_b
b_b
	cmp.w	#20,mouse_g
	bmi.b	no_dg
	clr.w	mouse_g
	beq.w	gauche
no_dg:	cmp.w	#20,mouse_d
	bmi.b	no_dd
	clr.w	mouse_d
	beq.w	Droite
no_dd:	cmp.w	#20,mouse_H
	bmi.b	no_dh
	clr.w	mouse_H
	beq.b	Haut
no_dh:	cmp.w	#20,mouse_B
	bmi.b	no_db
	clr.w	mouse_b
	beq.b	Bas
no_db:	Rts			; ajoute a coord les resultat algebrique trouve
;-----------------------------------------------------------------------------
Mouse_h:	dc.w	0
Mouse_b:	dc.w	0
Mouse_g:	dc.w	0
Mouse_d:	dc.w	0
