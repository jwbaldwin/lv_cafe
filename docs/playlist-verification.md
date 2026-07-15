# Playlist verification — September 8, 2026

Three videos per theme. Each accepted video was loaded through the YouTube IFrame API in a browser at localhost, reached PLAYING, and advanced its playback time over a two-second sample. Verified between 13:14 and 13:17 UTC. This is a point-in-time embed check, not a guarantee of future availability or playback in every region.

| Theme | Verified videos |
| --- | --- |
| spring | [ZMjdwYVmnog](https://www.youtube.com/watch?v=ZMjdwYVmnog) · [hODhrZlpcgo](https://www.youtube.com/watch?v=hODhrZlpcgo) · [aP139Pah2c8](https://www.youtube.com/watch?v=aP139Pah2c8) |
| summer | [NWw1ZuDIjlw](https://www.youtube.com/watch?v=NWw1ZuDIjlw) · [gUbNlN_SqpE](https://www.youtube.com/watch?v=gUbNlN_SqpE) · [-VjOjBLpMws](https://www.youtube.com/watch?v=-VjOjBLpMws) |
| autumn | [pa6CyLN3wPY](https://www.youtube.com/watch?v=pa6CyLN3wPY) · [X59TpY0qtHE](https://www.youtube.com/watch?v=X59TpY0qtHE) · [hrd0MSGc2Lk](https://www.youtube.com/watch?v=hrd0MSGc2Lk) |
| winter | [XVSL1DgGGiw](https://www.youtube.com/watch?v=XVSL1DgGGiw) · [tONVgIvdk0A](https://www.youtube.com/watch?v=tONVgIvdk0A) · [S-4hwfyK-XQ](https://www.youtube.com/watch?v=S-4hwfyK-XQ) |
| blade_runner | [4FhsjQ2xess](https://www.youtube.com/watch?v=4FhsjQ2xess) · [XB0e7pI3Q8I](https://www.youtube.com/watch?v=XB0e7pI3Q8I) · [svS19DWJ5t4](https://www.youtube.com/watch?v=svS19DWJ5t4) |
| christmas | [qwdzIECTqn8](https://www.youtube.com/watch?v=qwdzIECTqn8) · [wQwqjzdwIyw](https://www.youtube.com/watch?v=wQwqjzdwIyw) · [Rnx08JFs6nQ](https://www.youtube.com/watch?v=Rnx08JFs6nQ) |
| cozy | [tIMtzkZ93gg](https://www.youtube.com/watch?v=tIMtzkZ93gg) · [s6XIt0vUq6A](https://www.youtube.com/watch?v=s6XIt0vUq6A) · [AUT4ZdXi37s](https://www.youtube.com/watch?v=AUT4ZdXi37s) |
| locked_in | [00fOyOzuSfM](https://www.youtube.com/watch?v=00fOyOzuSfM) · [EN0A5derVo0](https://www.youtube.com/watch?v=EN0A5derVo0) · [9M4jZuqdw04](https://www.youtube.com/watch?v=9M4jZuqdw04) |
| morning_coffee | [3E0iUbAnCsM](https://www.youtube.com/watch?v=3E0iUbAnCsM) · [337OKHV3BRI](https://www.youtube.com/watch?v=337OKHV3BRI) · [1fueZCTYkpA](https://www.youtube.com/watch?v=1fueZCTYkpA) |
| rainy_day | [DEWzT1geuPU](https://www.youtube.com/watch?v=DEWzT1geuPU) · [3u0wlqe8lVk](https://www.youtube.com/watch?v=3u0wlqe8lVk) · [lCrqRhCt-oM](https://www.youtube.com/watch?v=lCrqRhCt-oM) |

Rejected `yw4WXw9kiDg`: public search result, but embedding returned YouTube error 150. Replaced with `svS19DWJ5t4`, which passed.

The app skips unavailable/private/embedding-disabled videos, tries each video at most once per failure sequence, and uses the existing title area if a whole theme is unavailable. Browser autoplay restrictions are handled separately from dead videos.
