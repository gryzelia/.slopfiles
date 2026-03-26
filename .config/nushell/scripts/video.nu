const OUTPUT_DIR = ([~ .ffmpeg output] | path join | path expand)

export def yt-upscale [
    file_name: string
    --output_name (-o): string
    --resolution (-r): int = 1440
    --crf (-C): float
    --minrate (-m): string = '10m'
    --maxrate (-M): string = '30m'
    --avgrate (-b): string = '25m'
    --preset (-p): string = 'medium'
    --profile : string = 'high'
    --fps (-f): float = 60.0
    --cpu (-c)
    --upscale (-s): string = 'neighbor'
] {
    if not ($OUTPUT_DIR | path exists) {
        mkdir $OUTPUT_DIR
    }
    let $output_file_path = (
        [$OUTPUT_DIR (
            if $output_name == null {
                $file_name | path basename
            } else {
                $output_name
            }
        )] | path join
    )
    let $encoder = (if $cpu { 'libx264' } else { 'h264_nvenc' })
    let $ffmpeg_args = (
    (if not $cpu { [
        -hwaccel_output_format cuda
    ]} else {
        []
    }) ++
    [    
        -i $file_name 
        -vf $'"scale=-1:($resolution):flags=($upscale)"'
        -c:v $encoder
        -profile:v $profile
        -bf 2
        -g ($fps / 2)
        -coder 1
        # -pix_fmt yuv420p
    ] ++
    (if $crf == null { [
        -b:v $avgrate
        -minrate $minrate
        -maxrate $maxrate
    ]} else { [
        -crf $crf
    ]}) ++
    [
        -f mp4
        $output_file_path 
    ])
    run-external ffmpeg $ffmpeg_args
}

export def clear-output [] {
    rm -rf ([OUTPUT_DIR *] | path join)
}

def compress-videos [
    file_paths: list<string>
    video_codec: string
    audio_codec: string
    output_format: string
    crf: float 
    preset: string
    threads: int
    output_dir: string
] {
    let ffmpeg_global_args = [
        '-c:v' $video_codec
        '-preset' $preset
        '-crf' $crf # TODO: cqp/bitrate support
        '-c:a' $audio_codec
        '-map' 0
        '-map_metadata' 0
        '-f' $output_format
    ]
    $file_paths | par-each -t $threads { |file_path|
        let $file_name = (file_path | path basename)
        let $output_path = ($output_dir | path join $file_name)
        let $ffmpeg_file_args = ($ffmpeg_global_args | prepend ['-i' $file_path] | append $output_path)
        run-external ffmpeg $ffmpeg_file_args
    }
}

# TODO: decide on interface for providing a series of files
