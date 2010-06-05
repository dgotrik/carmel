. ~graehl/isd/hints/aliases.sh
. ~graehl/isd/hints/bashlib.sh
set -o pipefail
eff=~graehl/bin/eff

function graph {
    local y=$1
    local ylbl="$2"
    local ylbldistance=${3:-'0.7"'}
    local obase=$alignbase.y=$y.`filename_from $ylbl`
    local of=$obase.png
    local ops=$obase.ps
    plboth $obase -prefab lines data=$irp pointsym=none x=1 y=$y ylbl="$ylbl" ylbldistance=$ylbldistance xlbl=iter title="$annealdesc$desc" ystubfmt '%4g' ystubdet="size=6" -scale 1.4
    echo $of
    graphps="$graphps $ops"
}

function graph2 {
    local y=$1
    local ylbl=$2
    local y2=$3
    local ylbl2=$4
    local ylbldistance=${3:-'0.7"'}
    local obase=$alignbase.y=$y.`filename_from $ylbl`.y2=$y2.`filename_from $ylbl2`
    local of=$obase.png
    local ops=$obase.ps
        #yrange=0
    set -x
    plboth $obase -prefab lines data=$irp x=1 pointsym=none pointsym2=none y=$y name="$ylbl" y2=$y2 name2="$ylbl2" ylbldistance=$ylbldistance xlbl=iter title="$annealdesc$desc" ystubfmt '%4g' ystubdet="size=6" linedet2="style=1" -scale 1.4
    set +x
    echo $of
    graphps="$graphps $ops"
}

function vizsub {
    echo -- vizsub "$@"
    vizlimit=${vizlimit:-20}
    local limarg
    if [ $vizlimit -lt $inlimit ] ; then
        limarg="-u $vizlimit"
    fi
    nviz=${nviz:-6}
    lang=${lang:-eng}
    local in=$1
    comment=${comment:-$in}
    local alignb=${2:-$in}
    local vizout=$alignb.first$nviz
    local vizpdf=$vizout.pdf
    allvizpdf="$allvizpdf $vizpdf"
#        echo lang=$lang vizalign $vizout $vaopt
    if [ "$skipviz" ] || [ ! -f $alignb.a ] ; then
        echo skipping $alignb.a
    else
        ./subset-training.py --align-in=$alignb.a --info-in=$alignb.info --etree-in=$alignb.e-parse --comment="$comment" -l 10 $limarg -n $nviz --inbase=$in --outbase=$vizout $vizsubopt
        showcmd=1 lang=$lang vizalign $vizout $vaopt && echo $vizout.pdf
    fi
}

function main {
    wd=${wd:-exp}
    noised=${noised:-4}
    iter=${iter:-50}
    in=${in:-10k}
    inlimit=${inlimit:-30}
    vizlimit=${vizlimit:-30}
    nin=${nin:-100000}
    nviz=${nviz:-6}
    temp0=${temp0:-1}
    tempf=${tempf:-1}
    vizhead=${vizhead:-2}
    until=${until:-5}
    lang=${lang:-chi}
    if [ "$justgraph" ] ; then
        skip=1
        skipviz=1
    fi
    if [ "$nomono" ] ; then
        mono=
        noise=${noise:-0}
        vizall=1
        desc="${desc}vs. GIZA++"
    else
        mono=1
        lang=eng
        desc="${desc}vs. monotone"
    fi
    noise=${noise:-.1}
    if false && [ "$noise" != 0 ] ; then
        desc="${desc}, skewed +-$noised with prob=$noise"
    fi
    if [ "$vizrecall" ] ; then
        vizro=--skip-includes-identity
    elif [ "$vizall" ] ; then
        vizro=
    else
        vizro=--skip-identity
    fi
    vizsubopt=${vizsubopt:-$vizro}
    [ "$vizall" ] || vaopt=-s

    mkdir -p $wd
    ntrain=`nlines $in.f`
    showvars_required wd noise iter in nviz nin temp0 tempf vizhead lang until
    showvars_optional vizsubopt justgraph skip vizrecall vizall mono nomono skipviz every
    if [ "$tempf" != 1 -o "$temp0" != 1 ] ; then
        annealarg="--tempf=$tempf"
        a0arg="--temp0=$temp0"
        annealdesc="tempf=$tempf "
        annealf=".tempf=$tempf"
        [ "$newf" ] && [ "$temp0" != 1 ] && annealf=".temp0=$temp0$annealf" && annealdesc="temp0=$temp0 $annealdesc"
    fi
    if [ "$mono" ] ; then
        oname=mono
        monoarg=--monotone
    else
        oname=`basename $in`
        monoarg=
    fi

    if [ "$nin" -gt "$ntrain" ] ; then
        echo "corpus $in has only $ntrain lines"
    else
        oname=first-$nin.$oname
    fi
    inm=$oname.0$noise
    set -e
    sub=$wd/$inm
    if ! [ "$skip" ] ; then
        ls $sub.* || true
        if [ "$clobber" ] || [ ! -f $sub.nonce ] ; then
         echo "generating $sub.*"
         ./subset-training.py -n $nin -u $inlimit --pcorrupt=$noise --dcorrupt=$noised $monoarg --inbase=$in --outbase=$sub
         touch $sub.nonce
        fi
    fi
    desc="$desc "`head -1 $sub.info | perl -pe 's/line \d+//'`
    alignbase=$sub.iter=$iter$annealf

    [ "$noise" == 0 ] && cp $sub.a $sub.a-gold

    out=$alignbase.out
    log=$alignbase.log
    if ! [ "$skip" ] ; then
        set -x
        everyarg=""
        [ "$every" ] && everyarg="--alignments-every=$every"
        ./gextract.py $a0arg $annealarg $everyarg --alignments-until $until --notest --golda $sub.a-gold --alignment-out $alignbase.a --inbase=$sub --iter=$iter "$@" 2>&1 >$out | tee $log
        set +x
    fi
#pr=" `lastpr $log`"
    if ! [ "$noviz" ] ; then
        comment="iter=$iter"
        irp=$alignbase.irp
        $eff -f 'iter,R,log10(cache-prob),P,n-1count,model-size' -missing 0 -allow-missing 2 $log > $irp
        graphps=""
        if [ `nlines $irp` -gt 0 ] ; then
            graph2 2 "alignment recall" 4 "alignment precision"
            graph 3 "sample logprob"
            grep -q "n-1count" $log && graph 5 "# of 1 count rules"
            grep -q "model-size" $log  && graph 6 "model size (characters)"
#    graph 2 "alignment-recall"
#    graph 4 "alignment-precision"
        else
            warn "no iterations finished in logfile"
        fi
        allvizpdf=""

        vizsub $sub $alignbase
        if [ "$every" ] ; then
            set +e
            for i in  ghkm `seq 0 $iter`; do
                afb=$alignbase.i=$i
                af=$afb.a
                [ -f $af ] && vizsub $sub $afb 2>/dev/null
            done
        fi
        if [ "$vizhead" -gt 0 ] ; then
            currydef pdfheadn pdfrange 1 $vizhead
            mapreduce_files pdfheadn pdfcat $graphps $allvizpdf > $alignbase.all.head-$vizhead.pdf
        fi
        ls $alignbase*.pdf
        ls $alignbase*.png
    fi
    ls $alignbase*.a
    showvars pr out log graphps
    grep zeroprob $log || echo "no zeroprob"
}

main;exit