function Get-R18DataObject {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Position = 0)]
        [string]$Name,
        [Parameter(Position = 1)]
        [string]$Url
    )

    begin {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Function started"
        $movieDataObject = @()
    }

    process {
        if ($Url) {
            $r18Url = $Url
        } else {
            $r18Url = Get-R18Url -Name $Name
        }

        if ($null -ne $R18Url) {
            try {
                $webRequest = Invoke-WebRequest -Uri $r18Url

                $movieDataObject = [pscustomobject]@{
                    Url             = $r18Url
                    ContentId       = Get-R18ContentId -WebRequest $webRequest
                    Id              = Get-R18Id -WebRequest $webRequest
                    Title           = Get-R18Title -WebRequest $webRequest
                    Date            = Get-R18ReleaseDate -WebRequest $webRequest
                    Year            = Get-R18ReleaseYear -WebRequest $webRequest
                    Runtime         = Get-R18Runtime -WebRequest $webRequest
                    Director        = Get-R18Director -WebRequest $webRequest
                    Maker           = Get-R18Maker -WebRequest $webRequest
                    Label           = Get-R18Label -WebRequest $webRequest
                    Series          = Get-R18Series -WebRequest $webRequest
                    Rating          = Get-R18Rating -WebRequest $webRequest
                    Actress         = (Get-R18Actress -WebRequest $webRequest).Name
                    Genre           = Get-R18Genre -WebRequest $webRequest
                    ActressThumbUrl = (Get-R18Actress -WebRequest $webRequest).ThumbUrl
                    CoverUrl        = Get-R18CoverUrl -WebRequest $webRequest
                    ScreenshotUrl   = Get-R18ScreenshotUrl -WebRequest $webRequest
                    TrailerUrl      = Get-R18TrailerUrl -WebRequest $webRequest
                }
            } catch {
                throw $_
            }
        }

        #$movieDataObject | Format-List | Out-String | Write-Debug
        Write-Output $movieDataObject
    }

    end {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Function ended"
    }
}

function Get-R18ContentId {
    param (
        [object]$WebRequest
    )

    process {
        $contentId = (((($WebRequest.Content -split '<dt>Content ID:<\/dt>')[1] -split '<br>')[0]) -split '<dd>')[1]
        $contentId = Convert-HtmlCharacter -String $contentId
        Write-Output $contentId
    }
}

function Get-R18Id {
    param (
        [object]$WebRequest
    )

    process {
        $id = (((($WebRequest.Content -split '<dt>DVD ID:<\/dt>')[1] -split '<br>')[0]) -split '<dd>')[1]
        $id = Convert-HtmlCharacter -String $id
        Write-Output $Id
    }
}

function Get-R18Title {
    param (
        [object]$WebRequest
    )

    process {
        $title = (($WebRequest.Content -split '<cite itemprop=\"name\">')[1] -split '<\/cite>')[0]
        $title = Convert-HtmlCharacter -String $title
        Write-Output $Title
    }
}

function Get-R18ReleaseDate {
    param (
        [object]$WebRequest
    )

    process {
        $releaseDate = (($WebRequest.Content -split '<dd itemprop=\"dateCreated\">')[1] -split '<br>')[0]
        $releaseDate = ($releaseDate.Trim() -replace '\.', '') -replace ',', ''
        $month, $day, $year = $releaseDate -split ' '

        # Convert full month names to abbreviated values due to non-standard naming conventions on R18 website
        if ($month -eq 'June') {
            $month = 'Jun'
        } elseif ($month -eq 'July') {
            $month = 'Jul'
        } elseif ($month -eq 'Sept') {
            $month = 'Sep'
        }

        # Convert the month name to a numeric value to conform with CMS datetime standards
        $month = [array]::indexof([cultureinfo]::CurrentCulture.DateTimeFormat.AbbreviatedMonthNames, "$month") + 1
        $releaseDate = Get-Date -Year $year -Month $month -Day $day -Format "yyyy-MM-dd"
        Write-Output $releaseDate
    }
}

function Get-R18ReleaseYear {
    param (
        [object]$WebRequest
    )

    process {
        $releaseYear = Get-R18ReleaseDate -WebRequest $WebRequest
        $releaseYear = ($releaseYear -split '-')[0]
        Write-Output $releaseYear
    }
}

function Get-R18Runtime {
    param (
        [object]$WebRequest
    )

    process {
        $length = ((($WebRequest.Content -split '<dd itemprop="duration">')[1] -split '\.')[0]) -replace 'min', ''
        $length = Convert-HtmlCharacter -String $length
        Write-Output $length
    }
}

function Get-R18Director {
    param (
        [object]$WebRequest
    )

    process {
        $director = (($WebRequest.Content -split '<dd itemprop="director">')[1] -split '<br>')[0]
        $director = Convert-HtmlCharacter -String $director

        if ($director -eq '----') {
            $director = $null
        }

        Write-Output $director
    }
}

function Get-R18Maker {
    param (
        [object]$WebRequest
    )

    process {
        $maker = ((($WebRequest.Content -split '<dd itemprop="productionCompany" itemscope itemtype="http:\/\/schema.org\/Organization\">')[1] -split '<\/a>')[0] -split '>')[1]
        $maker = Convert-HtmlCharacter -String $maker
        Write-Output $maker
    }
}

function Get-R18Label {
    param (
        [object]$WebRequest
    )

    process {
        $label = ((($WebRequest.Content -split '<dt>Label:<\/dt>')[1] -split '<br>')[0] -split '<dd>')[1]
        $label = Convert-HtmlCharacter -String $label
        Write-Output $label
    }
}

function Get-R18Series {
    param (
        [object]$WebRequest
    )

    process {
        $series = (((($WebRequest.Content -split '<dt>Series:</dt>')[1] -split '<\/a><br>')[0] -split '<dd>')[1] -split '>')[1]
        $series = Convert-HtmlCharacter -String $series

        if ($series -like '</dd*') {
            $series = $null
        }

        Write-Output $series
    }
}

function Get-R18Rating {
    param (
        [object]$WebRequest
    )

    process {
        $rating = ''
        Write-Output $rating
    }
}

function Get-R18Genre {
    param (
        [object]$WebRequest
    )

    begin {
        $genreArray = @()
    }

    process {
        $genreHtml = ((($WebRequest.Content -split '<div class="pop-list">')[1] -split '<\/div>')[0] -split '<\/a>') -split '>'

        foreach ($genre in $genreHtml) {
            $genre = $genre.trim()
            if ($genre -notmatch 'https:\/\/www\.r18\.com\/videos\/vod\/movies\/list\/id=(.*)' -and $genre -ne '') {
                $genre = Convert-HtmlCharacter -String $genre
                $genreArray += $genre
            }
        }

        Write-Output $genreArray
    }
}

function Get-R18Actress {
    param (
        [object]$WebRequest
    )

    begin {
        $movieActress = @()
        $movieActressThumb = @()
    }

    process {
        $movieActressHtml = (($WebRequest.Content -split '<div itemprop="actors" data-type="actress-list" class="pop-list">')[1] -split '<div class="product-categories-list product-box-list">')[0]
        $movieActressHtml = $movieActressHtml -replace '<a itemprop="url" href="https:\/\/www\.r18\.com\/videos\/vod\/movies\/list\/id=(.*)\/pagesize=(.*)\/price=all\/sort=popular\/type=actress\/page=(.*)\/">', ''
        $movieActressHtml = $movieActressHtml -replace '<span itemscope itemtype="http:\/\/schema.org\/Person">', ''
        $movieActressHtml = $movieActressHtml -split '<\/a>'

        foreach ($actress in $movieActressHtml) {
            if ($actress -match '<span itemprop="name">') {
                $movieActress += (($actress -split '<span itemprop="name">')[1] -split '<\/span>')[0]
            }
        }

        if ($movieActress -eq '----') {
            $movieActress = $null
        }

        foreach ($actress in $movieActress) {
            $movieActressHtml = $WebRequest.Content -split '\n'
            $movieActressHtml = $movieActressHtml | Select-String -Pattern 'src="https:\/\/pics.r18.com\/mono\/actjpgs\/(.*).jpg"' -AllMatches
            foreach ($actressThumb in $movieActressHtml) {
                $actressName = Convert-HtmlCharacter -String ((($actressThumb -split '<img alt="')[1] -split '"')[0])
                if ($actress -match $actressName) {
                    $movieActressThumb += (($actressThumb -split 'src="')[1] -split '"')[0]
                }
            }
        }

        $movieActressObject = [pscustomobject]@{
            Name     = $movieActress
            ThumbUrl = $movieActressThumb
        }

        Write-Output $movieActressObject
    }
}

function Get-R18CoverUrl {
    param (
        [object]$WebRequest
    )

    process {
        $coverUrl = (($WebRequest.Content -split '<div class="box01 mb10 detail-view detail-single-picture">')[1] -split '<\/div>')[0]
        $coverUrl = (($coverUrl -split 'src="')[1] -split '">')[0]
        Write-Output $coverUrl
    }
}

function Get-R18ScreenshotUrl {
    param (
        [object]$WebRequest
    )

    begin {
        $screenshotUrl = @()
    }

    process {
        $screenshotHtml = (($WebRequest.Content -split '<ul class="js-owl-carousel clearfix">')[1] -split '<\/ul>')[0]
        $screenshotHtml = $screenshotHtml -split '<li>'
        foreach ($screenshot in $screenshotHtml) {
            $screenshot = $screenshot -replace '<p><img class="lazyOwl" ', ''
            $screenshot = (($screenshot -split 'data-src="')[1] -split '"')[0]
            if ($screenshot -ne '') {
                $screenshotUrl += $screenshot
            }
        }

        Write-Output $screenshotUrl
    }
}

function Get-R18TrailerUrl {
    param (
        [object]$WebRequest
    )

    begin {
        $trailerUrl = @()
    }

    process {
        $trailerHtml = $WebRequest.Content -split '\n'
        $trailerHtml = $trailerHtml | Select-String -Pattern 'https:\/\/awscc3001\.r18\.com\/litevideo\/freepv' -AllMatches

        foreach ($trailer in $trailerHtml) {
            $trailer = (($trailer -split '"')[1] -split '"')[0]
            $trailerUrl += $trailer
        }

        Write-Output $trailerUrl
    }
}
