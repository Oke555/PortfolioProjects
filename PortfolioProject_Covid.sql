SELECT * 
FROM PortfolioProject..CovidDeaths

SELECT * 
FROM PortfolioProject..CovidVaccinations

Select *
From PortfolioProject..CovidDeaths
Where continent is not null 
order by 3,4


--Retrieve COVID-19 cases for a specific date range

SELECT * 
FROM PortfolioProject..CovidDeaths
WHERE date BETWEEN '2020-08-01' AND '2021-06-30'


-- Select Data that we are going to be starting with

Select Location, date, total_cases, new_cases, total_deaths, population
From PortfolioProject..CovidDeaths
Where continent is not null 
order by 1,2


-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country

Select Location, date, total_cases,total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
Where location like '%Nigeria%'
and continent is not null 
order by 1,2

--Calculate the average number of daily deaths by location

SELECT location, AVG(cast(total_deaths as int)) AS avg_daily_deaths 
FROM PortfolioProject..CovidDeaths
group by location


-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
--Where location like '%states%'
order by 1,2


--Calculate daily new cases and deaths

SELECT date, total_cases - LAG(total_cases) OVER (ORDER BY date) AS new_cases,
       (cast(total_deaths as float)) - LAG(cast(total_deaths as float)) OVER (ORDER BY date) as new_deaths
FROM PortfolioProject..CovidDeaths


-- Countries with Highest Infection Rate compared to Population

Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
Group by Location, Population
order by PercentPopulationInfected desc


-- Countries with Highest Death Count per Population

Select Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
Where continent is not null 
Group by Location
order by TotalDeathCount desc


-- Showing contintents with the highest death count per population

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
Where continent is not null 
Group by continent
order by TotalDeathCount desc

--Calculate the percentage growth rate of cases

SELECT date, (total_cases - LAG(total_cases) OVER (ORDER BY date)) / LAG(total_cases) OVER (ORDER BY date) * 100 AS growth_rate
FROM PortfolioProject..CovidDeaths

--Calculate a 7-day moving average of deaths

SELECT date, total_deaths,
       AVG(cast(total_deaths as int)) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_deaths
FROM PortfolioProject..CovidDeaths

-- GLOBAL NUMBERS

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
where continent is not null 
order by 1,2


--Find the location with the largest single-day increase in cases

SELECT location, date, total_cases - LAG(total_cases) OVER (PARTITION BY location ORDER BY date) AS daily_increase
FROM PortfolioProject..CovidDeaths
ORDER BY daily_increase DESC


--Calculate the case fatality rate (deaths as a percentage of cases) for each region

SELECT location, (cast(total_deaths as int) * 100.0) / total_cases AS case_fatality_rate
FROM PortfolioProject..CovidDeaths
WHERE total_cases > 0
ORDER BY case_fatality_rate DESC;

--Compare COVID-19 cases with vaccination rates to identify potential correlations

SELECT dea.location, dea.total_cases, v.people_fully_vaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations v 
ON dea.location = v.location AND dea.date = v.date

--Compare the average daily deaths before and after a certain vaccination rate threshold is reached

WITH CTE_VaccinationThreshold AS (
    SELECT date, SUM(cast(new_vaccinations as float)) OVER (ORDER BY date) AS total_vaccinations
    FROM PortfolioProject..CovidVaccinations
)
SELECT d.date, AVG(cast(d.total_deaths as float)) AS avg_deaths_before,
       AVG(CASE WHEN v.total_vaccinations >= 100000 THEN (cast(d.total_deaths as float)) ELSE NULL END) AS avg_deaths_after
FROM PortfolioProject..CovidDeaths d
JOIN CTE_VaccinationThreshold v ON d.date = v.date
GROUP BY d.date



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
order by 2,3

-- Using CTE to perform Calculation on Partition By in previous query

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
)
Select *, (RollingPeopleVaccinated/Population)*100 as PercentageVaccinated
From PopvsVac


-- Using Temp Table to perform Calculation on Partition By in previous query

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date


Select *, (RollingPeopleVaccinated/Population)*100 as PercentageVaccinated
From #PercentPopulationVaccinated

-- Creating View to store data for later visualizations

Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 