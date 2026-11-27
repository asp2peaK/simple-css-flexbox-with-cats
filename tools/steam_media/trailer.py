import subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
S='/tmp/claude-0/-home-claude/0fa7620d-6560-519d-8fd8-414cd7d66eea/scratchpad'
lang=sys.argv[1]; out=sys.argv[2]
FONT='/home/claude/pickup/fonts/DejaVuSans-Bold.ttf'
T={'en':[('card','You run a parcel pickup point...'),('clip','counter',6),
 ('card','...for witches, orcs and skeletons'),('clip','warehouse',6),
 ('card','Spot the scammers'),('clip','scam',6),
 ('card','Play co-op with friends'),('clip','coop',6),
 ('card','Survive Chaos Mode'),('clip','chaos',6),
 ('card','Decorate your shop'),('clip','decor',6),
 ('card','Dress up in the magic mirror'),('clip','mirror',8),
 ('card','Beware the Dark Postmaster'),('clip','boss',6),
 ('end','NOT MY PARCEL!','Wishlist now on Steam')],
 'ru':[('card','Ты работаешь в пункте выдачи...'),('clip','counter',6),
 ('card','...для ведьм, орков и скелетов'),('clip','warehouse',6),
 ('card','Лови мошенников'),('clip','scam',6),
 ('card','Играй вместе с друзьями'),('clip','coop',6),
 ('card','Выживи в режиме хаоса'),('clip','chaos',6),
 ('card','Укрась свой пункт'),('clip','decor',6),
 ('card','Наряжайся у волшебного зеркала'),('clip','mirror',8),
 ('card','Берегись Тёмного Почтмейстера'),('clip','boss',6),
 ('end','NOT MY PARCEL!','Добавь в желаемое в Steam')]}[lang]
W,H=1280,720; FPS=30
tmp=f'{S}/tr_{lang}'; os.makedirs(tmp,exist_ok=True)
def bg_from(clip):
    d=f'{S}/clips/{clip}_{lang}'
    fr=sorted(os.listdir(d)); im=Image.open(f'{d}/{fr[len(fr)//2]}').convert('RGB').resize((W,H))
    im=im.filter(ImageFilter.GaussianBlur(14))
    return Image.blend(im,Image.new('RGB',(W,H),(20,12,8)),0.6)
def text(im,s,size,y,col=(255,200,90)):
    d=ImageDraw.Draw(im); f=ImageFont.truetype(FONT,size)
    w=d.textlength(s,font=f); d.text(((W-w)/2,y),s,font=f,fill=col,stroke_width=max(3,size//14),stroke_fill=(30,15,40))
segs=[]
for i,it in enumerate(T):
    seg=f'{tmp}/s{i:02d}.mp4'
    if it[0]=='clip':
        d=f'{S}/clips/{it[1]}_{lang}'; dur=it[2]
        cmd=['ffmpeg','-y','-v','error','-framerate',str(FPS),'-i',f'{d}/f_%05d.png','-t',str(dur),
             '-vf',f'scale={W}:{H}:flags=lanczos,fade=t=in:st=0:d=0.25,fade=t=out:st={dur-0.25}:d=0.25,format=yuv420p','-r',str(FPS),'-c:v','libx264','-crf','18','-preset','medium',seg]
    else:
        nxt=next((x[1] for x in T[i+1:] if x[0]=='clip'),'boss')
        im=bg_from(nxt if it[0]=='card' else 'counter')
        if it[0]=='card':
            text(im,it[1],52,H//2-34); dur=2.0
        else:
            text(im,it[1],110,H//2-110,(255,170,60)); text(im,it[2],44,H//2+50,(255,255,255)); text(im,"2peaK's Studio",28,H-70,(200,190,180)); dur=4.0
        p=f'{tmp}/c{i:02d}.png'; im.save(p)
        cmd=['ffmpeg','-y','-v','error','-loop','1','-framerate',str(FPS),'-i',p,'-t',str(dur),
             '-vf',f'fade=t=in:st=0:d=0.3,fade=t=out:st={dur-0.3}:d=0.3,format=yuv420p','-r',str(FPS),'-c:v','libx264','-crf','18',seg]
    subprocess.run(cmd,check=True); segs.append(seg)
open(f'{tmp}/list.txt','w').write(''.join(f"file '{s}'\n" for s in segs))
subprocess.run(['ffmpeg','-y','-v','error','-f','concat','-safe','0','-i',f'{tmp}/list.txt','-c','copy',f'{tmp}/video.mp4'],check=True)
dur=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f'{tmp}/video.mp4']))
M='/home/claude/pickup/assets/sfx/'
subprocess.run(['ffmpeg','-y','-v','error','-i',M+'music_game.wav','-i',M+'music_chaos.wav','-i',M+'music_boss.wav',
 '-filter_complex',f'[0][1]acrossfade=d=1.5[a];[a][2]acrossfade=d=1.5,atrim=0:{dur},afade=t=in:d=0.5,afade=t=out:st={dur-2.5}:d=2.5[m]',
 '-map','[m]','-c:a','aac','-b:a','192k',f'{tmp}/music.m4a'],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-i',f'{tmp}/video.mp4','-i',f'{tmp}/music.m4a','-c:v','copy','-c:a','copy','-shortest','-movflags','+faststart',out],check=True)
print(out, round(dur,1),'s')
