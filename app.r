# Installs dashHtmlComponents, dashCoreComponents, and dashTable
# and will update the component libraries when a new package is released


# Installs dash bootstrap
library(devtools)
library(dash)
library(dashTable)
library(dashHtmlComponents)
library(dashBootstrapComponents)
library(dashCoreComponents)

library(plotly)
library(ggplot2)
library(tidyverse)
library(GGally)
library(ggcorrplot)
library(corrplot)
library(readr)
library(stringr)
library(plyr)
library(glue)


#############################################
## APP AND FUNCTIONAL APP OBJECTS
#############################################

#app <- Dash$new(external_stylesheets = "https://codepen.io/chriddyp/pen/bWLwgP.css")
app = Dash$new(external_stylesheets = dbcThemes$BOOTSTRAP)
#app <- Dash$new()
app$config['suppress_callback_exceptions'] = TRUE


colors <- list(background = 'white', text = 'black')

pageTitle <- htmlH1('Wine Vision', style = list(textAlign = 'left', color = colors$text))

get_header <- function() {
  header = htmlDiv(
    list(
      htmlDiv(
        list(
          htmlDiv(
            htmlP("WineVision Dashboard"),
            className = "seven columns main-title"),
        htmlDiv(
          list(
            dccLink("Learn more",
                    href = "/WineVision/learn-more",
                    className = "learn-more-button")),
          className = "twelve columns")
        ),
      className = "twelve columns")
      ),
    className = "row"
    )
  return(header)
  }


get_menu <- function() {
  menu = htmlDiv(
    list(
      dccLink(
        "Quality Distributions",
        href="/WineVision/Quality-Distributions",
        className="tab"),
      dccLink(
        "Correlation",
        href="/WineVision/Wine-Types",
        className="tab first"),
      dccLink(
        "Exploration",
        href="/WineVision/Quality-Factors",
        className="tab"),
      dccLink(
        "Raw Data",
        href="/WineVision/Wine-table",
        className="tab")
      ),
    className="rowrow alltab "
    )
  return(menu)
  }

Header <- htmlDiv(list(get_header(), htmlBr(), get_menu()))

Menu <- htmlDiv(list(get_menu()))

#############################################
## DATA
#############################################

df <- wine <- read.csv("data/processed/wine_quality.csv")
# need an extra ID column for linking plots ~ Rain
wine$id <- as.character(1:nrow(wine))


# df <- wine_quality <- read.csv("data/processed/wine_quality.csv")
# gsub("(mg/dm^3)","",colnames(df),fixed = TRUE)->cn
# gsub("(g/dm^3)","",cn,fixed = TRUE)->cn
# gsub("(g/cm^3)","",cn,fixed = TRUE)->cn
# gsub("(%)","",cn,fixed = TRUE)->cn
# str_trim(cn, side = c("right"))->cn
# colnames(df)<-cn


# Eric's code - I like it and would like to use it on my page so it's here now ~ Luka :)
variables <- colnames(wine) # Just rename all vars instead of some <--> subset(df, select = -c(Wine, Quality.Factor, Quality.Factor.Numeric)))

variablesNoUnits <- gsub("\\.\\..*$","", variables) # Remove units
variablesNoUnits <- gsub("\\."," ", variablesNoUnits) # Replace dots with spaces
# IF THIS GENERATES A PARSE ERROR ANYWHERE, simply replace "varibale name with space" --> "`varibale name with space`"

colnames(wine) <- variablesNoUnits
# Units in order of variables
units <- c(' ', '(g/dm^3)', '(g/dm^3)', '(g/dm^3)', '(g/dm^3)', '(g/dm^3)', '(mg/dm^3)', '(mg/dm^3)', '(g/cm^3)', ' ', '(g/dm^3)', '(%)', ' ', ' ', ' ')

## Luka
# I could probably put this in the wrangling file
factors <- c(1, 13, 14, 15)
wine[, -factors] <- as.numeric(unlist(wine[, -factors]))
white <- wine[wine[,'Wine']=='white', ]
red <- wine[wine[,'Wine']=='red', ]
wine_type <- list('White' = white, 'Red' = red)


mu_white <- ddply(white, "`Quality Factor`", numcolwise(mean))
mu_red <- ddply(red, "`Quality Factor`",  numcolwise(mean))
mu_type <- list(mu_white, mu_red)

med_white <- ddply(white, "`Quality Factor`", numcolwise(median))
med_red <- ddply(red, "`Quality Factor`",  numcolwise(median))
med_type <- list(med_white, med_red)


contmode <- function(vector) {
  dens <- density(vector)
  maxx = dens$x[which.max(dens$y)]
  return(maxx)
}

mode_white <- ddply(white, "`Quality Factor`", numcolwise(contmode))
mode_red <- ddply(red, "`Quality Factor`",  numcolwise(contmode))
mode_type <- list(mode_white, mode_red)

stats <- list('Mean'=mu_type, 'Median'=med_type, 'Mode'=mode_type)

vars <- variable.names(wine)[-15] %>% as.vector()


#############################################
## APP LAYOUT
#############################################

app$layout(
  htmlDiv(
    list(
      # URL
      dccLocation(id = 'url', refresh=TRUE), # Changed from false
      #Content
      htmlDiv(id='page-content')
      )
    )
  )

################################
## Raw Data page

page_size <- 10

table_layout<-htmlDiv(list(
  Header,
  dbcContainer(
    dbcRow(list(
      # dbcCol(htmlDiv(
      #   dbcCard(
      #     dbcCardBody
      #     (list(
      #       htmlH5("WineVision dataset", className = "Card title"),
      #       htmlP("", className = "card-text")
      #     )
      #     )))),
      htmlBr(),
      dbcCol(htmlDiv(
        dashDataTable(
          style_table = list(overflowX = 'scroll'),
          id = 'table-sorting-filtering',
          columns = lapply(sort(colnames(df)),
                           function(colName){
                             list(
                               id = colName,
                               name = colName
                             )
                           }),
          page_current = 0,
          page_size = page_size,
          page_action = 'custom',
          
          filter_action = 'custom',
          filter_query = '',
          
          sort_action = 'custom',
          sort_mode = 'multi',
          sort_by = list()
        )
        
      ), width=10)
    )))))


app$callback(
  output = list(id = 'table-sorting-filtering', property = 'data'),
  params = list(input(id = 'table-sorting-filtering', property = 'page_current'),
                input(id = 'table-sorting-filtering', property = 'page_size'),
                input(id = 'table-sorting-filtering', property = 'sort_by'),
                input(id = 'table-sorting-filtering', property = 'filter_query')),
  function(page_current, page_size, sort_by, filters) {
    
    subdf <- df
    # filter
    if(filters != "") {
      
      conditions <- strsplit(filters, split = "&&")[[1]]
      
      not_show <- lapply(conditions,
                         function(condition) {
                           
                           splited_condition <- strsplit(condition, split = " ")[[1]]
                           # len should be 3
                           len <- length(splited_condition)
                           
                           condition <- if('contains' %in% splited_condition) {
                             
                             splited_condition[which('contains' == splited_condition)] <- "=="
                             
                             if(!grepl("\"", splited_condition[len]) & !grepl("'", splited_condition[len])) {
                               splited_condition[len] <- paste0("'", splited_condition[len], "'")
                             }
                             
                             paste0(splited_condition, collapse = " ")
                           } else if('=' %in% splited_condition) {
                             gsub('=', '==', condition)
                           } else if ('datestartswith' %in% splited_condition) {
                             gsub('datestartswith', '>=', condition)
                           } else condition
                           
                           subdf <<- subdf %>%
                             dplyr::filter(eval(parse(text = condition)))
                         })
    }
    
    # sort
    if(length(sort_by) != 0) {
      
      index <- lapply(sort_by,
                      function(sort){
                        if(sort[['direction']] == "asc") {
                          subdf[, sort[['column_id']]]
                        } else {
                          -xtfrm(subdf[, sort[['column_id']]])
                        }
                      })
      
      # sort by multi columns
      subdf <- subdf[do.call(order, index), ]
    }
    
    start_id <- (page_current * page_size + 1)
    end_id <- ((page_current + 1) * page_size)
    subdf[start_id:end_id, ]
  }
)

################################
## Quality Distributions Page - Luka

Quality_Distribution_layout <- htmlDiv(
  list(
    Header,
    htmlDiv(
      list(
        htmlBr(),
        htmlH4(
          "Wine Selection:",
          className = "graph__title"
          ),
        htmlBr(),
        dccDropdown(
          id = 'wine-select',
          options = list(list(label = 'White Wine', value = 1),
                        list(label = 'Red Wine', value = 2)),
          value = 1
          ),
        htmlBr(),
        dccDropdown(
          id = 'col-select',
          options = colnames(wine)[2:12] %>% purrr::map(function(col) list(label = col, value = which(colnames(wine)==col))),
          value = 9
          ),
        htmlBr(),
        dccDropdown(
          id = 'stat',
          options = list(list(label = 'Mean', value = 'Mean'),
                        list(label = 'Median', value = 'Median'),
                        list(label = 'Mode', value = 'Mode')),
          value = 'Mean'
          ),
        htmlBr(),
        dccGraph(id = 'density'),
        htmlBr(),
        dccGraph(id = 'stackeddensity')
      ),
    )
  )
)


app$callback(
  output(id = 'density', property = 'figure'),
  params = list(input(id = 'col-select', 'value'), 
                input(id = 'wine-select', 'value'),
                input(id = 'stat', 'value')),

  function(variable, winetype, stat) {

    coln <- sym(colnames(wine)[variable])

    plot <- ggplot(wine_type[[winetype]], aes(x = !!coln, fill = `Quality Factor`)) + 
            geom_density(alpha = 0.4) + ylab('Density') + xlab(glue('{as.character(coln)} {units[variable]}')) +
            geom_vline(data=stats[[stat]][[winetype]], aes(xintercept=!!coln, color=`Quality Factor`), linetype="dashed", size=0.5) +
            ggtitle(glue('Density Type: <b>Overlaid</b>')) +
            theme_classic() +
            theme(plot.title = element_text(size=14, hjust = 0.01),
                  axis.text.y = element_blank(), axis.ticks.y = element_blank(),
                  legend.title = element_blank(),
                  text = element_text(size = 16),
                  element_line(size = 1))
                  

    plot <- ggplotly(plot)
    plot <- plot %>% layout(
      #clickmode='event+select',
      legend = list(title=list(text='<b> Quality Levels </b>\n'), x = 0.85, y = 1, itemwidth = 40, tracegroupgap = 13),
      autosize = FALSE,
      width = 1100, height = 500)

    plot
  }
)

app$callback(
  output(id = 'stackeddensity', property = 'figure'),
  params = list(input(id = 'col-select', 'value'), 
                input(id = 'wine-select', 'value'),
                input(id = 'stat', 'value')),

  function(variable, winetype, stat) {

    coln <- sym(colnames(wine)[variable])

    plot <- ggplot(wine_type[[winetype]], aes(x = !!coln, fill = `Quality Factor`)) + 
            geom_density(alpha = 0.4, position="stack") + ylab('Density') + xlab(glue('{as.character(coln)} {units[variable]}')) +
            geom_vline(data=stats[[stat]][[winetype]], aes(xintercept=!!coln, color=`Quality Factor`), linetype="dashed", size=0.5) +
            ggtitle(glue('Density Type: <b>Stacked</b>')) +
            theme_classic() +
            theme(plot.title = element_text(size=14, hjust = 0.01),
                  axis.text.y = element_blank(), axis.ticks.y = element_blank(),
                  legend.title = element_blank(),
                  text = element_text(size = 16),
                  element_line(size = 1))
                  

    plot <- ggplotly(plot)
    plot <- plot %>% layout(
      legend = list(title=list(text='<b> Quality Levels </b>\n'), x = 0.85, y = 1, itemwidth = 40, tracegroupgap = 13),
      autosize = FALSE,
      width = 1100, height = 500)

    plot
  }
)
#Quality.Factor
################################
## Quality Factor Analysis Page - RAIN


Quality_Factors_layout <- htmlDiv(
  list(
    Header,
    htmlDiv(
      list(
        htmlDiv(
          list(
            htmlDiv(
              list(
                htmlBr(),
                htmlImg(
                  # https://elite-brands.com/blog/wine-ratings-q3/
                  src  =  "/assets/rating.png", width = "100%",
                  className = "app__menu__img"
                )
              ), className = "app__header__logo"
            )
          ), className = "app__header"
        ),
        htmlDiv(
          list(
            # scatter plot
            htmlDiv(
              list(
                htmlDiv(
                  list(
                    htmlH4('Select your variables:'),
                    htmlH5('X-axis'),
                    dccDropdown(
                      id='xcol-select',
                      options = wine %>% select_if(is.numeric) %>%
                        colnames %>%
                        purrr::map(function(xcol) list(label = xcol, value = xcol)), 
                      value='Chlorides'),
                    htmlH5('Y-axis'),
                    dccDropdown(
                      id='ycol-select',
                      options = wine %>% select_if(is.numeric) %>%
                        colnames %>%
                        purrr::map(function(ycol) list(label = ycol, value = ycol)), 
                      value='pH'),
                    htmlBr(),
                    htmlH4("Interactive Plots:", className = "graph__title"),
                    htmlBr(),
                    htmlH4("Drag your mouse to select a range!"))
                ),
                dccGraph(
                  id = "plot-area"
                )
              ), className = "two-thirds column wind__speed__container"
            ),
            htmlDiv(
              list(
                # bar plot
                htmlDiv(
                  list(
                    htmlDiv(
                      list(
                        htmlH4(
                          "Select your wine type:",
                          className = "graph__title"
                        )
                      )
                    ),
                    htmlDiv(
                      list(
                        dccRadioItems(
                          id = 'wine-type',
                          options = list(list(label = 'White Wine', value = 'white'),
                                         list(label = 'Red Wine', value = 'red')),
                          value = 'white',
                          labelStyle = list(display = 'inline-block')
                        )
                      ), className = "radioItem"
                    ),
                    dccGraph(
                      id = "bar-plot"
                    )
                  ), className = "graph__container first"
                ),
                # 2nd bar plot
                htmlBr(),
                htmlDiv(
                  list(
                    htmlDiv(
                      list(
                        htmlH4(
                          "% Quality Factors", className = "graph__title"
                        )
                      )
                    ),
                    dccGraph(
                      id = "bar-plot2")
                  ), className = "graph__container second"
                )
              ), className = "one-third column histogram__direction"
            )
          ), className = "app__content"
        )
      ), className = "app__container"
    )
  )
)


app$callback(
  output = list(id='plot-area', property='figure'),
  params = list(input(id='xcol-select', property='value'),
                input(id='ycol-select', property='value'),
                input(id='wine-type', property='value')),
  
  function(xcol, ycol, type) {
    wine_dif <- wine %>% subset(Wine == type)
    scatter <- ggplot(wine_dif) + 
      aes(x = !!sym(xcol), y = !!sym(ycol), color = `Quality Factor`, text = id) + 
      geom_point(alpha = 0.7) + ggthemes::scale_color_tableau()
    ggplotly(scatter, tooltip = 'text') %>% layout(dragmode = 'select')
  }
)


app$callback(
  output = list(id='bar-plot', property='figure'),
  params = list(input(id='plot-area', property='selectedData'),
                input(id='wine-type', property='value')),
  
  function(selected_data, type) {
    wine_dif <- wine %>% subset(Wine == type)
    wine_id <- selected_data[[1]] %>% purrr::map_chr('text')
    p <- ggplot(wine_dif %>% filter(id %in% wine_id)) +
      aes(x = Quality,
          fill = `Quality Factor`) +
      geom_bar(width = 0.6, alpha = 0.5) +
      ggthemes::scale_fill_tableau()
    ggplotly(p, tooltip = 'text') %>% layout(dragmode = 'select')
  }
)


app$callback(
  output = list(id='bar-plot2', property='figure'),
  params = list(input(id='plot-area', property='selectedData'),
                input(id='wine-type', property='value')),
  
  function(selected_data, type) {
    wine_dif <- wine %>% subset(Wine == type)
    wine_id <- selected_data[[1]] %>% purrr::map_chr('text')
    
    b <- ggplot(wine_dif %>% filter(id %in% wine_id)) +
      aes(x = `Quality Factor`,
          fill = `Quality Factor`) +
      geom_bar(aes(y = (..count..)/sum(..count..))) +
      theme(axis.text.x=element_blank()) +
      ggthemes::scale_fill_tableau()
    ggplotly(b, tooltip = 'y') %>% layout(dragmode = 'select')
  }
)



################################
## Wine Type Comparison Page - Eric 

Wine_Types_layout <- htmlDiv(
  list(
    Header,
    htmlDiv(
      list(
        htmlBr(),
        dbcContainer(
          dbcRow(list(
            dbcCol(list(
              htmlH4("Choose Factor Levels"),
              dbcRow(list(
                dbcCol(list(
                  htmlH5("Quality"),
                  dccChecklist(id = "quality",
                               options = list(
                                 list("label" = "Below Average", "value" = 0),
                                 list("label" = "Average", "value" = 1),
                                 list("label" = "Above Average", "value" = 2)
                               ),
                               value = list(0,1,2),
                               labelStyle = list("display" = "inline-block")
                  )
                )),
                dbcCol(list(
                  htmlH5("Wine Type"),
                  dccChecklist(id = "winetype",
                               options = list(
                                 list("label" = "White Wines", "value" = 'white'),
                                 list("label" = "Red Wines", "value" = 'red')
                               ),
                               value=list('white', 'red'),
                               labelStyle = list("display" = "inline-block")
                  )
                ))
              )),
              htmlBr(),
              dccGraph(
                id = "matrix")
            )),
            dbcCol(list(
              htmlH4("Choose Scatterplot Axes"),
              htmlH5("x-axis"),
              dccDropdown(id = "x-axis",
                          options = colnames(wine)[2:12] %>% purrr::map(function(col) list(label = col, value = which(colnames(wine)==col))),
                          value = 3),
              htmlH5("y-axis"),
              dccDropdown(
                id = "y-axis",
                options = colnames(wine)[2:12] %>% purrr::map(function(col) list(label = col, value = which(colnames(wine)==col))),
                value = 9
              ),
              dccGraph(id = "scatter")
            ))
          ))
        ),
        htmlBr()
        ),
      className = "twelve columns"
    )
  )
)

# Make Graphs

app$callback(
  output("matrix", "figure"),
  list(input("winetype", "value"),
       input("quality", "value")),
  function(winetype, quality){
    # Subset to our desired variable levels
    winex <- subset(wine, Wine %in% winetype)
    winex <- subset(winex, `Quality Factor Numeric` %in% quality)
    winex <- subset(winex, select = -c(Wine, `Quality Factor`, `Quality Factor Numeric`, `id`))
    if (quality == 1) { # The correlation plot breaks if only average quality chosen since there is only one value (six)
      winex <- subset(winex, select = -c(Quality))
    }

    # Create a correlation matrix and reorder it alphabetically
    corr <- cor(winex)
    order <- corrMatOrder(corr, "alphabet")
    corr <- corr[order,order]
    p <- ggcorrplot(corr,
                 hc.order = TRUE,
                 type = "lower",
                 outline.color = "white",
                 color = c("darkblue", "lightgray", "darkred"))
    ggplotly(p, height = 550, width = 550) %>% layout(margin())
  }
)

app$callback(
  output("scatter", "figure"),
  params = list(input("x-axis", "value"),
                input("y-axis", "value"),
                input("winetype", "value"),
                input("quality", "value")),

  function(x, y, winetype, quality){
    # Subset to our desired variable levels
    winex <- subset(wine, Wine %in% winetype)
    winex <- subset(winex, `Quality Factor Numeric` %in% quality)

    colx <- sym(colnames(winex)[x])
    coly <- sym(colnames(winex)[y])

    p <- ggplot(winex, aes(x = !!colx, y = !!coly)) + geom_bin2d() +
      scale_fill_gradient(low="lightgray", high = "darkred") +
      theme_minimal() +
      geom_smooth(method = lm)

    ggplotly(p, height = 450, width = 425) %>% layout(margin())
  }
)

################################
## Learn More Page

learn_more_layout <- htmlDiv(
  list(
    Header,
    htmlBr(),
    htmlDiv(
      list(
        # Row 3
        htmlDiv(
          list(
            htmlH3('Motivation'),
            htmlP("With 36 billion bottles of wine produced each year, wine makers
                    are constantly looking for ways to outperform the competition and
                    create the best wines they can. Portugal in particular is second
                    in the world for per-capita wine consumption and eleventh for
                    wine production, creating over 600,000 litres per year.
                    Given that physicochemical components are fundamental to a wine's
                    quality, those who understand this aspect of wine will have a
                    greater edge into crafting an enjoyable and profitable product.")
            ),
          className="product"
          )
        ),
      className="twelve columns"
      ),
    htmlDiv(
      dccMarkdown(
        
    "
    ### Welcome!!!
    Hello and thank you for stopping by the Wine Vision App! 
    
    Feel free to visit out [GitHub homebase](https://github.com/ubco-mds-2020-labs/WineVision-R-group8) for more information on the project. 
    

    ### The problem
    Wine making has always been a traditional practice passed down for many generations; yet, some of wine's secrets are still a mystery to most people, even wine producers! So how are we supposed to craft the perfect wine without knowing what makes it perfect (speaking from both a consumer and business perspective)?
    
    In general, wine quality evaluation is assessed by physicochemical tests and sensory analysis. It's the roadmap to improving a wine. However the relationship between physicochemical structure and subjective quality is complex and no individual component can be used to accurately predict a wine's quality. The interactions are as important as the components themselves. 
    
    From a business perspective, producers are constantly looking for ways to outperform the competition by creating the best wine they can. Those who understand the fundamental physiochemical aspects of wine will have a greater edge into crafting an enjoyable and profitable product. So, we introduce to you the *Wine Vision Dashboard*.
    
    ### The solution
    **Our interactive dashboard will allow users to explore how a number of physicochemical variables interact and determine the subjective quality of a wine. Wine producers, wine enthusiasts, and curious individuals can all make use of this dashboard to discover these elusive relationships.** 


    ### App Description
    The dashboard has four pages:
    
    **Distribution:** Investigate how different physiochemical variables are distributed in different groups.
    
    **Correlation:** Study how different predictors correlate to each other.
    
    **Exploration:** Discover the proportions of wines at different quality levels within specific ranges for each variable.
    
    **Raw Data:** See the dataset itself.
    
    
    ### The Data
    Portugal is second in the world for per-capita wine consumption [2](https://www.nationmaster.com/nmx/ranking/wine-consumption-per-capita) and eleventh for wine production [3](https://en.wikipedia.org/wiki/List_of_wine-producing_regions), so by no coincidence we built our dashboard on the famous Portuguese wine quality data set from Cortez et al., 2009. 
    
    Data was collected from Vinho Verde wines originating from the northwest regions of Portugal. These wines have a medium alcohol content, and are particularly sought for their freshness in summer months. Each wine sample was evaluated by at least three sensory assessors (using blind tastes) who graded the wine from 0 (worst) to 10 (best). The final quality score is given by the median of these evaluations.
    
    The dataset consists of the physiochemical composition and sensory test results for 4898 white and 1599 red wine samples which were collected from May 2004 to February 2007. Each wine sample contains 12 variables that provide the acidity properties (fixed acidity, volatile acidity, citric acid, pH), sulphides contents (free sulfur dioxide, total sulfur dioxide, sulphates), density related properties (residual sugar, alcohol, density), and salt content (chlorides). It also contains quality as the response variable. In order to improve classification analyses, we define a new variable, quality_factor. Any wine with a quality score less than six is classified as “below average”, a score of 6 is “average”, and above 6 is “above average”.

    ### A Fun Usage Scenario
    Alice is a winemaker in British Columbia's Okanagan Valley. She would like to create a new summer wine and hopes to take inspiration from the Vinho Verde wines, known for their refreshing qualities. Alice seeks our dashboard to better understand what wine attributes she should focus on to provide a tasting experience comparable to the very best Vinho Verde wines. However, there are some physicochemical properties she has little control over due to the soils and grape species available to her. Due to the above average alkalinity of Okanagan soil, she knows that her wines will typically be less acidic than true Vinho Verde wines, and the altitude means the chloride content will be lower as well. She wants to try to optimize the variables she has control over to make the best wine possible. She looks to our dashboard to see how Vinho Verde wines with higher pH and lower chloride content tend to fare. Looking at the interactive scatterplots, she sees that wines which have values within her possible ranges for these variables tend to be of very poor quality when they are also high in residual sugar, but less sweet wines are of good quality. She then consults the histograms and sees that there are not very many wines available that have these properties, so she knows that she will not have much direct competition should she go forward with this design. A few years later, she released this wine to broad critical acclaim and millions in profit.
    
    
    ### Get involved
    If you think you can help in any of the areas listed above (and we bet you can) or in any of the many areas that we haven't yet thought of (and here we're *sure* you can) then please check out our [contributors' guidelines](https://github.com/ubco-mds-2020-labs/WineVision/blob/main/CONTRIBUTING.md) and our [roadmap](https://github.com/ubco-mds-2020-labs/WineVision/pull/1).
    
    Please note that it's very important to us that we maintain a positive and supportive environment for everyone who wants to participate. When you join us we ask that you follow our [code of conduct](https://github.com/ubco-mds-2020-labs/WineVision/blob/main/CODE_OF_CONDUCT.md) in all interactions both on and offline.
    

    ### Contact us
    If you want to report a problem or suggest an enhancement we'd love for you to [open an issue](https://github.com/ubco-mds-2020-labs/WineVision/issues) at this github repository because then we can get right on it.
    

    ### Data Citation
    Paulo Cortez, University of Minho, Guimarães, Portugal, http://www3.dsi.uminho.pt/pcortez
    A. Cerdeira, F. Almeida, T. Matos and J. Reis, Viticulture Commission of the Vinho Verde Region(CVRVV), Porto, Portugal @2009
    "
))))
#style = list("font-size"="1.625rem")

#############################################
## APP PAGE CALLBACKS
#############################################

app$callback(output = list(id='page-content', property = 'children'),
             params = list(input(id='url', property = 'pathname')),
             display_page <- function(pathname) {
               if (pathname == '/WineVision/Quality-Factors') {
                 return(Quality_Factors_layout)
               }
               else if (pathname == "/WineVision/Quality-Distributions") {
                 return(Quality_Distribution_layout)
               }
               else if (pathname == "/WineVision/Wine-Types") {
                 return(Wine_Types_layout)
               }
               else if (pathname == "/WineVision/learn-more") {
                 return(learn_more_layout)
               }
               else if (pathname == "/WineVision/Wine-table") {
                 return(table_layout)
               }
               else {
                 return(Wine_Types_layout)
               }
             }
)


#############################################
## RUN APP
#############################################

app$run_server(host = '0.0.0.0') # 0.0.0.0 Needed for Heroku

