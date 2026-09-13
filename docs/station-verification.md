# Station video verification — September 8, 2026

Initial verification: three videos per theme. Each accepted video was loaded through the YouTube IFrame API in a browser at localhost, reached PLAYING, and advanced its playback time over a two-second sample. Verified between 13:14 and 13:17 UTC. This is a point-in-time embed check, not a guarantee of future availability or playback in every region.

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


## September 8 evening curation update

Fourteen replacement/additional videos reached PLAYING and advanced in the local YouTube IFrame API checker on September 9, 02:47–02:50 UTC (September 8 evening in New York). Thumbnails were inspected for scene fit and animal characters. Five reported `isLive: true`; other additions are recordings and use a 30-second intro floor plus clock-based joining. This does not remove YouTube network buffering.

| Theme | Updated selection |
| --- | --- |
| summer | [Yr_5jRBH1JY](https://www.youtube.com/watch?v=Yr_5jRBH1JY) · [gUbNlN_SqpE](https://www.youtube.com/watch?v=gUbNlN_SqpE) · [-VjOjBLpMws](https://www.youtube.com/watch?v=-VjOjBLpMws) |
| blade_runner | [UjlMEqTu2KI](https://www.youtube.com/watch?v=UjlMEqTu2KI) (live at verification) · [mQahxfypquE](https://www.youtube.com/watch?v=mQahxfypquE) (live at verification) · [tyXeh8-U780](https://www.youtube.com/watch?v=tyXeh8-U780) |
| christmas | [qwdzIECTqn8](https://www.youtube.com/watch?v=qwdzIECTqn8) · [wQwqjzdwIyw](https://www.youtube.com/watch?v=wQwqjzdwIyw) · [Rnx08JFs6nQ](https://www.youtube.com/watch?v=Rnx08JFs6nQ) · [zI_W7rz3eXE](https://www.youtube.com/watch?v=zI_W7rz3eXE) · [t8C_sEWYKyg](https://www.youtube.com/watch?v=t8C_sEWYKyg) · [6toYzO9spWE](https://www.youtube.com/watch?v=6toYzO9spWE) |
| cozy | [cEn4c9JDy8A](https://www.youtube.com/watch?v=cEn4c9JDy8A) (live at verification) · [MYPVQccHhAQ](https://www.youtube.com/watch?v=MYPVQccHhAQ) · [M0lVOhvJajc](https://www.youtube.com/watch?v=M0lVOhvJajc) |
| locked_in | [00fOyOzuSfM](https://www.youtube.com/watch?v=00fOyOzuSfM) · [EN0A5derVo0](https://www.youtube.com/watch?v=EN0A5derVo0) · [mgYDCK8ygIM](https://www.youtube.com/watch?v=mgYDCK8ygIM) |
| morning_coffee | [UZiKR5HHXTo](https://www.youtube.com/watch?v=UZiKR5HHXTo) (live at verification) · [pfx4r7_WdP8](https://www.youtube.com/watch?v=pfx4r7_WdP8) · [blAFxjhg62k](https://www.youtube.com/watch?v=blAFxjhg62k) (live at verification) |

Preserved spring, autumn, winter, rainy day; summer slots 2–3; Locked In slots 1–2; and all three existing Christmas videos. Replaced all Blade Runner, Cozy, and Morning Coffee choices. Christmas now has six choices.

Rejected `f02mOEt11OQ` despite successful playback: cats appear beside the programmer. Chose `mgYDCK8ygIM`, a computer desk overlooking a city, instead. `vIlzvUsB6H0` also passed as an unused summer alternate. These unused candidates are not in the app catalog.

See [curation.md](curation.md) for the integrated Phoenix admin panel and saved taste guidance.
